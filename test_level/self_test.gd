extends Node
## Plays the test level without a player and checks what happens. The level adds this node
## when it is started with [code]--self-test[/code]:
## [codeblock lang=text]
## godot --headless --fixed-fps 60 res://test_level/test_level.tscn -- --self-test
## [/codeblock]
## It first checks that the level uses every class and every example in
## [code]character_system/[/code], so a new part can't be left out of the level unnoticed.

## Classes that can't be placed in a level.
const NOT_CONTENT: Array[StringName] = [&"EffectContext", &"WorldEvents", &"NameCheck"]
const SYSTEM := "res://character_system/"

var _passed: int = 0
var _failed: int = 0
var _classes: Dictionary[StringName, bool] = {}  # Script classes found in the level.
var _files: Dictionary[String, bool] = {}  # Resource files found in the level.
var _scanned: Dictionary[int, bool] = {}

@onready var _level: Node3D = get_parent()
@onready var _player: CharacterBody3D = _level.get_node(^"Player")


func _ready() -> void:
	await _frames(5)
	_check_coverage()
	await _check_pickups()
	await _check_shrines_and_hazards()
	await _check_combat()
	print("%d passed, %d failed" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


func check(condition: bool, what: String) -> void:
	_passed += 1 if condition else 0
	_failed += 0 if condition else 1
	print("%s  %s" % ["ok  " if condition else "FAIL", what])


func _check_coverage() -> void:
	_scan_node(_level)
	var unused: PackedStringArray = []
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		var path: String = entry["path"]
		if path.begins_with(SYSTEM) and entry["class"] not in NOT_CONTENT \
				and not (load(path) as Script).is_abstract() and not _classes.has(entry["class"]):
			unused.append(entry["class"])
	check(unused.is_empty(), "the level uses every class: %s" % ", ".join(unused))
	var missing: PackedStringArray = []
	var folders: Array[String] = [SYSTEM + "examples"]
	while not folders.is_empty():
		var folder: String = folders.pop_back()
		for name: String in DirAccess.get_directories_at(folder):
			folders.append(folder.path_join(name))
		for name: String in DirAccess.get_files_at(folder):
			if name.get_extension() in ["tres", "tscn"] and not _files.has(folder.path_join(name)):
				missing.append(name)
	check(missing.is_empty(), "the level uses every example: %s" % ", ".join(missing))


func _check_pickups() -> void:
	var bag := Component.of(_player, Inventory) as Inventory
	var gear := Component.of(_player, Equipment) as Equipment
	var items: Array[ItemData] = []
	for pickup: ItemPickup in _level.find_children("*", "ItemPickup", true, false):
		items.append(pickup.item)
		await _stand_on(pickup)
	check(items.all(func(item: ItemData) -> bool: return bag.count(item) > 0),
			"walking over the %d pickups puts every item in the bag" % items.size())
	check([&"weapon", &"ring", &"cloak", &"neck"].all(
			func(slot: StringName) -> bool: return gear.equipped.has(slot)),
			"a weapon is drawn and the ring, cloak and amulet are put on")
	check(ComponentManager.stat_of(_player, &"max_health") == 125.0,
			"the ring of vigor raises max health to 125")
	var switch := Component.of(_player, WeaponSwitch) as WeaponSwitch
	for index in switch.weapons().size():
		switch.select(index)
		await _frames(2)
	check(gear.equipped[&"weapon"] == switch.weapons()[-1], "every weapon can be drawn in turn")
	switch.select(0)


func _check_shrines_and_hazards() -> void:
	var statuses := Component.of(_player, Statuses) as Statuses
	var worn: int = statuses.active.size()
	var pads: Array[Node] = _level.get_node(^"Shrines").find_children("*", "EffectZone", true, false)
	for pad in pads:
		if pad.name != &"Cleanse":
			await _stand_on(pad)
	check(statuses.active.size() == worn + pads.size() - 1,
			"each of the %d shrines gives its passive" % (pads.size() - 1))
	await _stand_on(_level.get_node(^"Shrines/Cleanse"))
	check(statuses.active.size() == worn, "the cleanse pad takes them away, and only them")
	for zone in _level.get_node(^"Hazards").find_children("*", "EffectZone", true, false):
		if zone.name not in [&"Stunned", &"Rooted", &"Silenced"]:
			await _stand_on(zone)
	check(statuses.has_tag(&"poison") and not statuses.has_tag(&"fire"),
			"the zones apply their statuses; the fireproof cloak keeps burning off")
	var brain := Component.of(_player, Brain) as Brain
	await _stand_on(_level.get_node(^"Hazards/Stunned"))
	check(brain.is_blocked(), "the stun pad stops the player")
	await _frames(150)
	check(not brain.is_blocked(), "and the stun wears off")


func _check_combat() -> void:
	var target: Node3D = _level.get_node(^"Targets/Plain")
	var health := Component.of(target, Health) as Health
	# A little to the left and looking slightly up, so the gun in the right hand points at
	# the head: shots leave from the weapon, not from the camera.
	_player.global_position = target.global_position + Vector3(-0.15, 0.1, 6)
	_player.rotation = Vector3.ZERO
	(_player.get_node(^"Head/Camera3D") as Camera3D).rotation.x = 0.05
	await _frames(10)
	await _tap(&"primary")
	check(health.maximum() - health.current == 20.0,
			"a rifle shot at a dummy's head does double damage: %s" % health.current)
	var mana := Pool.named(_player, &"mana")
	await _tap(&"ability_3")
	await _frames(60)
	check(mana.current < mana.maximum(), "casting Fireball costs mana")
	var own := Component.of(_player, Health) as Health
	own.change(-60.0)
	var before: float = own.current
	await _tap(&"use_health_potion")
	check(own.current > before, "a potion heals")
	var grenades: ItemData = _level.quick_items[&"throw_grenade"]
	var bag := Component.of(_player, Inventory) as Inventory
	var held: int = bag.count(grenades)
	health.revive()
	await _tap(&"throw_grenade")
	await _frames(150)
	check(bag.count(grenades) == held - 1 and health.current < health.maximum(),
			"a thrown grenade leaves the bag and its blast hurts the dummy")
	health.change(-1000.0)
	check(health.is_dead(), "a dummy can be killed")
	await _frames(roundi(_level.RESPAWN_TIME * 60) + 30)
	check(not health.is_dead(), "and stands back up")
	var fighters: Array[Node] = _level.get_node(^"Arena").find_children("*", "CharacterBody3D")
	check(fighters.any(func(who: Node) -> bool: return _is_hurt(who)),
			"the soldiers in the arena fight each other")


func _is_hurt(who: Node) -> bool:
	var health := Component.of(who, Health) as Health
	return health.current < health.maximum()


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _stand_on(place: Node3D) -> void:
	_player.global_position = place.global_position + Vector3.UP * 0.1
	_player.velocity = Vector3.ZERO
	await _frames(4)


func _tap(action: StringName) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)
		await _frames(3)


# Notes the script classes and resource files a node and everything under it uses.
func _scan_node(node: Node) -> void:
	_files[node.scene_file_path] = true
	_scan_object(node)
	for child in node.get_children():
		_scan_node(child)


func _scan_object(object: Object) -> void:
	if _scanned.has(object.get_instance_id()):
		return
	_scanned[object.get_instance_id()] = true
	var script := object.get_script() as Script
	while script:
		_classes[script.get_global_name()] = true
		script = script.get_base_script()
	if object is Resource:
		_files[(object as Resource).resource_path] = true
	if object is PackedScene:
		var instance: Node = (object as PackedScene).instantiate()
		_scan_node(instance)
		instance.free()
	elif object.get_script() or object is Node:
		for property: Dictionary in object.get_property_list():
			if property["usage"] & PROPERTY_USAGE_STORAGE:
				_scan_value(object.get(property["name"]))


func _scan_value(value: Variant) -> void:
	if value is Object and is_instance_valid(value) and not value is Node:
		_scan_object(value)
	elif value is Array:
		for item: Variant in value:
			_scan_value(item)
	elif value is Dictionary:
		for key: Variant in value:
			_scan_value(key)
			_scan_value(value[key])
