extends SceneTree
## Times the system with many characters. Not a test: run it by hand and compare two versions.
## [codeblock lang=text]
## godot --headless --fixed-fps 60 -s tests/benchmark.gd
## [/codeblock]
## Each character has ten components and an equipped rifle, and walks across a floor.

const EX := "res://character_system/starter_pack/"
const HITS := 20000


func _init() -> void:
	await process_frame
	for count: int in [100, 300]:
		print("%d armed characters walking: %.2f ms per frame" % [count, await walk(count)])
	await micro()
	quit()


func make_character(pos: Vector3) -> CharacterBody3D:
	var body := CharacterBody3D.new()
	body.position = pos
	var shape := CollisionShape3D.new()
	shape.shape = CapsuleShape3D.new()
	shape.position.y = 1.0
	var hand := Node3D.new()
	hand.name = "Hand"
	hand.position = Vector3(0, 1, -0.8)
	var motor := CharacterMotor.new()
	motor.add_child(WalkMode.new())
	motor.add_child(AirMode.new())
	var gear := Equipment.new()
	gear.sockets = { &"weapon": ^"../Hand" }
	for node: Node in [shape, hand, ComponentManager.new(), Statuses.new(), Health.new(),
			Brain.new(), motor, Faction.new(), Inventory.new(), gear, WeaponSwitch.new()]:
		body.add_child(node)
	return body


## The mean time of one frame over [param count] frames, in milliseconds.
func frames(count: int) -> float:
	var start: int = Time.get_ticks_usec()
	for i in count:
		await process_frame
	return (Time.get_ticks_usec() - start) / 1000.0 / count


## The best of three runs of 200 frames with [param count] characters walking.
func walk(count: int) -> float:
	var level := Node3D.new()
	root.add_child(level)
	var ground := StaticBody3D.new()
	var slab := CollisionShape3D.new()
	slab.shape = BoxShape3D.new()
	(slab.shape as BoxShape3D).size = Vector3(400, 1, 400)
	ground.add_child(slab)
	ground.position.y = -0.5
	level.add_child(ground)
	var side: int = ceili(sqrt(count))
	for i in count:
		@warning_ignore("integer_division")
		var c := make_character(Vector3((i % side) * 2.5 - side, 0.1, (i / side) * 2.5 - side))
		level.add_child(c)
		(Component.of(c, Inventory) as Inventory).add(load(EX + "items/rifle.tres"))
		(Component.of(c, Brain) as Brain).move_dir = Vector3.RIGHT if i % 2 else Vector3.BACK
	await frames(30)
	var best: float = INF
	for run in 3:
		best = minf(best, await frames(200))
	level.queue_free()
	await frames(3)
	return best


## Prints the mean time of one call of [param what], in microseconds.
func time(label: String, count: int, what: Callable) -> void:
	var start: int = Time.get_ticks_usec()
	for i in count:
		what.call()
	print("%s: %.2f us" % [label, (Time.get_ticks_usec() - start) / float(count)])


func micro() -> void:
	var a := make_character(Vector3(500, 0, 0))
	var b := make_character(Vector3(503, 0, 0))
	root.add_child(a)
	root.add_child(b)
	await frames(2)
	var brain := Component.of(a, Brain) as Brain
	time("find(Health)", 200000, func() -> void: brain.find(Health))
	time("Component.of(node, Health)", 200000, func() -> void: Component.of(a, Health))
	time("stat_of(move_speed)", 200000,
			func() -> void: ComponentManager.stat_of(a, &"move_speed"))
	for who: Node in [a, b]:
		# So nobody dies during the timing.
		(Component.of(who, Health) as Health).max_value = 1e9
		(Component.of(who, Health) as Health).revive()
	var hit := DamageEffect.new()
	hit.amount = 0.001
	time("one damage hit", HITS, func() -> void: hit.apply(EffectContext.new(a, b)))
	(Component.of(b, Statuses) as Statuses).add(load(EX + "statuses/thorns.tres"))
	(Component.of(b, Statuses) as Statuses).add(load(EX + "statuses/warded.tres"))
	time("hit on a warded target with a thorns reply", HITS,
			func() -> void: hit.apply(EffectContext.new(a, b)))
	var many: Array[Node] = []
	for i in 300:
		many.append(make_character(Vector3(600 + i * 3, 0, 0)))
		root.add_child(many[-1])
	await frames(2)
	time("free one character", many.size(), func() -> void: many.pop_back().free())
