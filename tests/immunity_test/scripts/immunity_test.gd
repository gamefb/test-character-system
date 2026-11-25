extends Node3D
## Runs the immunity test: five characters walk their own track of zones and pickups at the
## same time, and each step is checked. Results show on screen and in the Output panel.
## When run headless, the game quits with exit code 0 if every check passed, 1 otherwise.
##
##   Knight  picks up a rifle, ammo, a flare gun and a fireproof cloak, shoots two dummies with
##           both guns, switches between them and drops one
##   Ghoul   Undead trait: immune to poison, not to fire
##   Golem   Construct trait: immune to fire and poison, but can still be warded
##   Diver   water makes it Wet (immune to fire) and puts out Burning
##   Cleric  a ward amulet only helps once it is equipped; ward circle and amulet hold it together

const BURNING := preload("res://tests/immunity_test/data/statuses/burning.tres")
const WARDED := preload("res://tests/immunity_test/data/statuses/warded.tres")
const RIFLE := preload("res://tests/immunity_test/data/items/rifle.tres")
const AMMO := preload("res://tests/immunity_test/data/items/rifle_ammo.tres")
const CLOAK := preload("res://tests/immunity_test/data/items/fireproof_cloak.tres")
const AMULET := preload("res://tests/immunity_test/data/items/ward_amulet.tres")
const FLARE := preload("res://tests/immunity_test/data/items/flare_gun.tres")

## Seconds of game time before the test gives up.
@export var time_limit: float = 90.0

var _passed: int = 0
var _failed: int = 0
var _lines: Array[String] = []
var _tracks_left: int = 0
# Character -> ids of statuses it refused.
var _refused: Dictionary[Node, Array] = {}
# Character -> health lost per hit, newest last.
var _hits: Dictionary[Node, Array] = {}

@onready var knight: CharacterBody3D = $Knight
@onready var ghoul: CharacterBody3D = $Ghoul
@onready var golem: CharacterBody3D = $Golem
@onready var diver: CharacterBody3D = $Diver
@onready var cleric: CharacterBody3D = $Cleric
@onready var dry_dummy: CharacterBody3D = $DryDummy
@onready var wet_dummy: CharacterBody3D = $WetDummy
@onready var results_label: Label = $HUD/Results


func _ready() -> void:
	for who in [knight, ghoul, golem, diver, cleric, dry_dummy, wet_dummy]:
		_record(who)
	get_tree().create_timer(time_limit, false).timeout.connect(_give_up)
	# Let zones see who starts inside them.
	await get_tree().physics_frame
	var tracks: Array[Callable] = [
		_knight_track,
		_ghoul_track,
		_golem_track,
		_diver_track,
		_cleric_track,
	]
	_tracks_left = tracks.size()
	for track in tracks:
		_run(track)


#region Helpers


## Equips the first [param data] that [param who] carries.
func wear(who: Node, data: ItemData) -> void:
	gear(who).equip(bag(who).first(data))


func bag(who: Node) -> Inventory:
	return Inventory.find_on(who)


func gear(who: Node) -> Equipment:
	return Equipment.find_on(who)


## Presses and releases [param action] on [param who]'s brain, like a player would, and waits
## until every component has had a frame to see it.
func press(who: Node, action: StringName) -> void:
	var brain := Brain.find_on(who)
	brain.press(action)
	await get_tree().process_frame
	await get_tree().process_frame
	brain.release(action)


## Walks [param who] along its track to [param x] and waits until it gets there.
func walk(who: Node3D, x: float) -> void:
	var brain := Component.of(who, WalkerBrain) as WalkerBrain
	brain.walk_to(Vector3(x, 0.0, who.global_position.z))
	await brain.arrived


func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, false).timeout


## Waits until [param condition] is true, or [param timeout] seconds pass.
func until(condition: Callable, timeout := 10.0) -> void:
	while not condition.call() and timeout > 0.0:
		await get_tree().process_frame
		timeout -= get_process_delta_time()


## Aims at [param target], pulls the trigger once and lets go.
func shoot(who: Node, target: Node3D) -> void:
	var brain := Brain.find_on(who)
	brain.aim_point = target.global_position + Vector3.UP
	brain.press(&"primary")
	await wait(0.1)
	brain.release(&"primary")
	await wait(0.3)


func health(who: Node) -> float:
	return Health.find_on(who).current


func has(who: Node, tag: StringName) -> bool:
	return Statuses.find_on(who).has_tag(tag)


func hold_count(who: Node, data: StatusData) -> int:
	var s = Statuses.find_on(who).active.get(data)
	return s.holds if s else 0


func bag_count(who: Node, data: ItemData) -> int:
	return bag(who).count(data)


func stacks_of(who: Node, data: ItemData) -> int:
	return bag(who).items.filter(
			func(item: ItemInstance) -> bool: return item.data == data).size()


func equipped(who: Node, slot: StringName) -> ItemData:
	var item: ItemInstance = gear(who).equipped.get(slot)
	return item.data if item else null


func rounds(who: Node) -> int:
	var item: ItemInstance = gear(who).equipped.get(&"weapon")
	return item.state.get(&"rounds", -1) if item else -1


## True if every hit since the list was cleared took exactly [param amount], and there was one.
func ticks_were(who: Node, amount: float) -> bool:
	var hits: Array = _hits[who]
	if hits.is_empty():
		return false
	return hits.all(func(hit: float) -> bool: return is_equal_approx(hit, amount))


func check(what: String, ok: bool) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
	var line: String = ("PASS  " if ok else "FAIL  ") + what
	print(line)
	_lines.append(line)
	results_label.text = "\n".join(_lines)


#endregion


#region Tracks


func _knight_track() -> void:
	await walk(knight, -13.0)
	check("Knight: first weapon picked up goes into the bag and is drawn",
			bag_count(knight, RIFLE) == 1 and equipped(knight, &"weapon") == RIFLE)
	await walk(knight, -10.0)
	check("Knight: 15 rounds of ammo picked up", bag_count(knight, AMMO) == 15)

	await walk(knight, -3.0)  # Through the fire patch.
	await wait(1.2)
	check("Knight: fire patch burns him", has(knight, &"fire") and health(knight) < 100.0)
	await walk(knight, 0.0)  # Onto the healing pad.
	var healed: Callable = func() -> bool:
		return not has(knight, &"fire") and is_equal_approx(health(knight), 100.0)
	await until(healed)
	check("Knight: healing pad heals him back to full after the burn ends",
			is_equal_approx(health(knight), 100.0))

	await walk(knight, 3.0)
	check("Knight: second ammo pickup stacks to 30 in one stack",
			bag_count(knight, AMMO) == 30 and stacks_of(knight, AMMO) == 1)
	# Past the flare gun, to the cloak.
	await walk(knight, 6.0)
	check("Knight: flare gun goes into the bag; the rifle stays drawn",
			bag_count(knight, FLARE) == 1 and equipped(knight, &"weapon") == RIFLE)
	check("Knight: cloak in the bag doesn't protect him",
			bag_count(knight, CLOAK) == 1 and not has(knight, &"fireproof"))
	wear(knight, CLOAK)
	check("Knight: wearing the cloak makes him fireproof", has(knight, &"fireproof"))

	_refused[knight].clear()
	# Back across the healing pad and through the fire.
	await walk(knight, -9.0)
	await wait(1.2)
	check("Knight: with the cloak, fire is refused and does no damage",
			not has(knight, &"fire") and is_equal_approx(health(knight), 100.0)
			and &"burning" in _refused[knight])

	gear(knight).unequip(&"cloak")
	# The item scene is freed at the end of the frame.
	await wait(0.1)
	check("Knight: taking off the cloak ends the immunity; he still carries it",
			not has(knight, &"fireproof") and bag_count(knight, CLOAK) == 1)
	await walk(knight, -3.0)  # Through the fire again.
	await wait(1.2)
	check("Knight: without the cloak he burns again", has(knight, &"fire"))

	await walk(knight, -14.0)  # To the shooting spot.
	await shoot(knight, dry_dummy)
	check("Knight: rifle does 10 to the dry dummy", is_equal_approx(health(dry_dummy), 90.0))
	await shoot(knight, wet_dummy)
	check("Knight: rifle does 15 to the wet dummy (+5 against wet)",
			is_equal_approx(health(wet_dummy), 85.0))
	await shoot(knight, dry_dummy)
	check("Knight: magazine of 3 is empty", rounds(knight) == 0)
	await shoot(knight, dry_dummy)
	check("Knight: empty rifle doesn't fire", is_equal_approx(health(dry_dummy), 80.0))
	await press(knight, &"reload")
	check("Knight: reload takes 3 rounds from the bag",
			rounds(knight) == 3 and bag_count(knight, AMMO) == 27)

	await press(knight, &"next_weapon")
	check("Knight: next_weapon switches to the flare gun", equipped(knight, &"weapon") == FLARE)
	await shoot(knight, dry_dummy)
	check("Knight: only the flare gun fires: 2 to the dry dummy, which catches fire",
			is_equal_approx(health(dry_dummy), 78.0) and has(dry_dummy, &"fire"))
	await shoot(knight, wet_dummy)
	check("Knight: the wet dummy takes the 2 but refuses Burning",
			is_equal_approx(health(wet_dummy), 83.0) and not has(wet_dummy, &"fire")
			and &"burning" in _refused[wet_dummy])
	await press(knight, &"previous_weapon")
	check("Knight: previous_weapon brings the rifle back with its 3 rounds",
			equipped(knight, &"weapon") == RIFLE and rounds(knight) == 3)
	bag(knight).remove_instance(bag(knight).first(RIFLE))  # Drop the rifle.
	await wait(0.1)
	check("Knight: dropping the held rifle draws the flare gun",
			equipped(knight, &"weapon") == FLARE and bag_count(knight, RIFLE) == 0)


func _ghoul_track() -> void:
	await walk(ghoul, -4.0)  # Through the poison bog.
	await wait(1.2)
	check("Ghoul (Undead): poison is refused and does no damage",
			not has(ghoul, &"poison") and is_equal_approx(health(ghoul), 100.0)
			and &"poisoned" in _refused[ghoul])
	await walk(ghoul, 4.0)  # Through the fire patch.
	await wait(1.2)
	check("Ghoul (Undead): fire still burns it", has(ghoul, &"fire") and health(ghoul) < 100.0)
	await walk(ghoul, 8.0)  # Onto the healing pad.
	await until(func() -> bool: return is_equal_approx(health(ghoul), 100.0))
	check("Ghoul (Undead): healing pad heals it", is_equal_approx(health(ghoul), 100.0))


func _golem_track() -> void:
	await walk(golem, -3.0)  # Through the fire patch.
	await wait(1.2)
	check("Golem (Construct): fire is refused",
			not has(golem, &"fire") and &"burning" in _refused[golem])
	await walk(golem, 4.0)  # Through the poison bog.
	await wait(1.2)
	check("Golem (Construct): poison is refused",
			not has(golem, &"poison") and &"poisoned" in _refused[golem])
	check("Golem (Construct): no damage taken", is_equal_approx(health(golem), 100.0))
	await walk(golem, 8.0)  # Into the ward circle.
	check("Golem (Construct): immunity is per tag, so the ward still lands", has(golem, &"ward"))


func _diver_track() -> void:
	await walk(diver, -10.0)  # Into the water.
	await wait(0.5)
	check("Diver: water makes it Wet and 40% slower",
			has(diver, &"wet")
			and is_equal_approx(ComponentManager.stat_of(diver, &"move_speed"), 3.0))
	# Out of the water (Dripping for 3 s) and straight through the fire.
	await walk(diver, -1.0)
	await wait(0.5)
	check("Diver: still dripping, so the fire is refused",
			not has(diver, &"fire") and &"burning" in _refused[diver]
			and is_equal_approx(health(diver), 100.0))
	check("Diver: speed is back to normal out of the water",
			is_equal_approx(ComponentManager.stat_of(diver, &"move_speed"), 5.0))
	await until(func() -> bool: return not has(diver, &"wet"))
	check("Diver: Dripping wears off", not has(diver, &"wet"))
	# Through the second fire patch, now dry.
	await walk(diver, 6.0)
	await wait(1.2)
	check("Diver: dry, it burns", has(diver, &"fire") and health(diver) < 100.0)
	await walk(diver, 10.0)  # Into the second pool while burning.
	await wait(0.1)
	check("Diver: water puts the burning out", not has(diver, &"fire") and has(diver, &"wet"))


func _cleric_track() -> void:
	await walk(cleric, -13.0)
	check("Cleric: amulet pickup goes into the bag", bag_count(cleric, AMULET) == 1)
	check("Cleric: an amulet in the bag doesn't ward", not has(cleric, &"ward"))
	_hits[cleric].clear()
	await walk(cleric, -4.0)  # Through the first fire patch, unwarded.
	await until(func() -> bool: return not has(cleric, &"fire"))
	check("Cleric: unwarded burn ticks do 4 each", ticks_were(cleric, 4.0))

	wear(cleric, AMULET)
	check("Cleric: wearing the amulet wards her", has(cleric, &"ward"))
	_hits[cleric].clear()
	await walk(cleric, 5.5)  # Through the second fire patch, warded.
	await until(func() -> bool: return not has(cleric, &"fire"))
	check("Cleric: warded burn ticks do 2 each", ticks_were(cleric, 2.0))

	# Into the ward circle, still wearing the amulet.
	await walk(cleric, 9.0)
	check("Cleric: amulet and circle both hold the ward", hold_count(cleric, WARDED) == 2)
	gear(cleric).unequip(&"neck")
	await wait(0.1)
	check("Cleric: taking off the amulet inside the circle keeps the ward", has(cleric, &"ward"))
	await walk(cleric, 12.0)  # Out of the circle.
	check("Cleric: leaving the circle ends the ward", not has(cleric, &"ward"))
	var before: float = health(cleric)
	await walk(cleric, 17.0)  # Through the poison bog.
	await wait(1.2)
	check("Cleric: no trait, so poison lands", has(cleric, &"poison") and health(cleric) < before)


#endregion


#region Bookkeeping


func _record(who: Node) -> void:
	_refused[who] = []
	_hits[who] = []
	var statuses := Statuses.find_on(who)
	statuses.refused.connect(
			func(data: StatusData, _source: Node) -> void: _refused[who].append(data.id))
	var health_component := Health.find_on(who)
	# In an array so the lambda can change it.
	var last := [health_component.current]
	health_component.changed.connect(func(current: float, _maximum: float) -> void:
		if current < last[0]:
			_hits[who].append(last[0] - current)
		last[0] = current)


func _run(track: Callable) -> void:
	await track.call()
	_tracks_left -= 1
	if _tracks_left == 0:
		_finish()


func _give_up() -> void:
	if _tracks_left > 0:
		check("Finished within %d seconds (%d tracks still running)" % [time_limit, _tracks_left],
				false)
		_tracks_left = 0
		_finish()


func _finish() -> void:
	var summary := "%d passed, %d failed" % [_passed, _failed]
	print(summary)
	_lines.append("\n" + summary)
	results_label.text = "\n".join(_lines)
	if DisplayServer.get_name() == "headless":
		get_tree().quit(1 if _failed > 0 else 0)


#endregion
