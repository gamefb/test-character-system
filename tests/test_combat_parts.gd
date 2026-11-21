extends GutTest
## Hitscan, ability cooldowns on game time, and teams as Godot groups.

const EX := "res://character_system/examples/"


func make_character(position := Vector3.ZERO, extra: Array[Node] = []) -> CharacterBody3D:
	var body := CharacterBody3D.new()
	body.position = position
	var shape := CollisionShape3D.new()
	shape.shape = CapsuleShape3D.new()
	shape.position.y = 1.0
	var hand := Node3D.new()
	hand.name = "Hand"
	# In front of the body, outside it.
	hand.position = Vector3(0, 1, -0.8)
	var gear := Equipment.new()
	gear.sockets = { &"weapon": ^"../Hand" }
	for node in [shape, hand, ComponentManager.new(), Health.new(), Brain.new(), gear] + extra:
		body.add_child(node)
	add_child_autofree(body)
	return body


func pull_trigger(who: Node) -> void:
	var brain := Component.of(who, Brain) as Brain
	brain.press(&"primary")
	# A press counts from the next frame; process_frame comes just before nodes run.
	for i in 3:
		await get_tree().process_frame
	brain.release(&"primary")


func test_hitscan_hits_the_target_and_not_its_wielder() -> void:
	var shooter: CharacterBody3D = make_character()
	# Behind the shooter: the shot crosses its own body.
	var target: CharacterBody3D = make_character(Vector3(0, 0, 6))
	var rifle: ItemData = load(EX + "items/rifle.tres")
	(Component.of(shooter, Equipment) as Equipment).equip(ItemInstance.new(rifle))
	(Component.of(shooter, Brain) as Brain).aim_point = target.global_position + Vector3.UP
	await get_tree().physics_frame
	await pull_trigger(shooter)
	assert_eq((Component.of(target, Health) as Health).current, 90.0)
	assert_eq((Component.of(shooter, Health) as Health).current, 100.0, "its own body is skipped")


func test_cooldown_blocks_reuse() -> void:
	var who: CharacterBody3D = make_character(Vector3.ZERO, [Abilities.new()])
	var abilities := Component.of(who, Abilities) as Abilities
	var heal: AbilityData = load(EX + "abilities/second_wind.tres")
	assert_true(abilities.use(heal))
	assert_false(abilities.use(heal))
	assert_almost_eq(abilities.cooldown_left(heal), heal.cooldown, 0.1)


func test_cooldown_waits_while_paused() -> void:
	var who: CharacterBody3D = make_character(Vector3.ZERO, [Abilities.new()])
	var abilities := Component.of(who, Abilities) as Abilities
	var heal: AbilityData = load(EX + "abilities/second_wind.tres")
	abilities.use(heal)
	var before: float = abilities.cooldown_left(heal)
	get_tree().paused = true
	OS.delay_msec(300)  # Real time passes...
	await get_tree().process_frame
	# The long frame shows up one frame later.
	await get_tree().process_frame
	get_tree().paused = false
	assert_almost_eq(abilities.cooldown_left(heal), before, 0.05, "...but no game time")


func faction(team: StringName, hostile_to: Array[StringName]) -> Faction:
	var f := Faction.new()
	f.team = team
	f.hostile_to = hostile_to
	return f


func test_teams_are_groups() -> void:
	var player: CharacterBody3D = make_character(Vector3.ZERO, [faction(&"player", [&"enemy"])])
	var grunt: CharacterBody3D = make_character(Vector3(5, 0, 0), [faction(&"enemy", [&"player"])])
	var crate := Node3D.new()
	# Anything in the group counts, Faction or not.
	crate.add_to_group(&"enemy")
	add_child_autofree(crate)
	var f := Component.of(player, Faction) as Faction
	assert_true(grunt.is_in_group(&"enemy"))
	assert_true(f.is_hostile(grunt))
	assert_false(f.is_hostile(player))
	assert_true(f.is_hostile(crate))
	assert_false(f.is_hostile(null))
	assert_eq(get_tree().get_nodes_in_group(&"enemy").size(), 2)


func test_changing_team_changes_group() -> void:
	var grunt: CharacterBody3D = make_character(Vector3.ZERO, [faction(&"enemy", [&"player"])])
	var f := Component.of(grunt, Faction) as Faction
	f.team = &"player"  # Charmed.
	assert_false(grunt.is_in_group(&"enemy"))
	assert_true(grunt.is_in_group(&"player"))
	grunt.remove_child(f)
	assert_false(grunt.is_in_group(&"player"), "removing Faction leaves the group")
	f.free()
