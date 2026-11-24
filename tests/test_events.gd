extends GutTest
## Hearing events: a component's on(), an event's signal from outside, every event at once, and
## the whole level through WorldEvents.


var world_heard: Array = []


func make_host(parts: Array = []) -> Node3D:
	var host := Node3D.new()
	for node: Node in [ComponentManager.new()] + parts:
		host.add_child(node)
	add_child_autofree(host)
	return host


func test_on_hears_one_event_until_the_component_stops() -> void:
	var listener := Listener.new()
	var host: Node3D = make_host([listener])
	var ctx := EffectContext.new(null, host)
	ComponentManager.notify(host, &"ping", ctx)
	ComponentManager.notify(host, &"pong", ctx)
	assert_eq(listener.heard, [ctx], "its own event and nothing else")
	host.remove_child(listener)
	ComponentManager.notify(host, &"ping", ctx)
	assert_eq(listener.heard.size(), 1, "unsubscribed when it stopped")
	host.add_child(listener)
	ComponentManager.notify(host, &"ping", ctx)
	assert_eq(listener.heard.size(), 2, "and subscribed again on restart, once")


func test_on_can_listen_to_another_host() -> void:
	var wielder: Node3D = make_host()
	var listener := Listener.new()
	listener.other = wielder
	var item: Node3D = make_host([listener])
	ComponentManager.notify(wielder, &"ping")
	assert_eq(listener.heard, [&"other"])
	item.remove_child(listener)
	ComponentManager.notify(wielder, &"ping")
	assert_eq(listener.heard.size(), 1, "undone when the component stops")
	listener.free()


func test_listening_to_a_host_that_is_freed_first_is_safe() -> void:
	var wielder: Node3D = make_host()
	var listener := Listener.new()
	listener.other = wielder
	var item: Node3D = make_host([listener])
	wielder.free()
	item.remove_child(listener)
	listener.free()
	pass_test("no error when the other manager is gone")


func test_listeners_hear_an_event_in_a_fixed_order() -> void:
	var listener := Listener.new()
	var host: Node3D = make_host([listener])
	var manager := ComponentManager.of(host)
	var log: Array = listener.log
	var world := func(_host: Node, _ctx: EffectContext) -> void: log.append(&"world")
	WorldEvents.event(&"ordered").connect(world)
	manager.event(&"ordered").connect(func(_ctx: EffectContext) -> void: log.append(&"first"))
	manager.event(&"ordered").connect(func(_ctx: EffectContext) -> void: log.append(&"second"))
	ComponentManager.notify(host, &"ordered")
	assert_eq(log, [&"every event", &"first", &"second", &"world"],
			"event_sent, then the event's own signal in connection order, then the world")
	WorldEvents.event(&"ordered").disconnect(world)


func test_an_event_is_an_ordinary_signal() -> void:
	var host: Node3D = make_host()
	var manager := ComponentManager.of(host)
	var count: Array = [0]
	var method := func(_ctx: EffectContext) -> void: count[0] += 1
	manager.event(&"ping").connect(method)
	assert_eq(manager.event(&"ping"), manager.event(&"ping"), "the same signal each time")
	ComponentManager.notify(host, &"ping")
	manager.event(&"ping").disconnect(method)
	ComponentManager.notify(host, &"ping")
	assert_eq(count[0], 1)
	manager.event(&"ready").connect(method)
	ComponentManager.notify(host, &"ready")
	assert_eq(count[0], 2, "an event may share its name with one of Node's own signals")


func test_a_freed_subscriber_is_dropped() -> void:
	var host: Node3D = make_host()
	var hud := Listener.new()
	ComponentManager.of(host).event(&"ping").connect(hud._on_ping)
	hud.free()
	ComponentManager.notify(host, &"ping")
	ComponentManager.notify(host, &"ping")
	pass_test("no error, and it's forgotten")


func test_lambdas_of_a_freed_object_are_dropped_too() -> void:
	var host: Node3D = make_host()
	var hud := Listener.new()
	hud.watch(host)
	ComponentManager.notify(host, &"ping")
	assert_eq(hud.heard, [&"lambda", &"world lambda"])
	hud.free()
	# Something new takes the freed object's place in memory; the lambdas must not reach it.
	var newcomer: Node3D = make_host()
	ComponentManager.notify(host, &"ping")
	ComponentManager.notify(newcomer, &"ping")
	pass_test("no error after the object that wrote them is gone")


func test_connections_end_when_the_listener_is_freed() -> void:
	var host: Node3D = make_host()
	var hud := Listener.new()
	hud.watch(host)
	ComponentManager.of(host).event(&"ping").connect(hud._on_ping)
	WorldEvents.event(&"ping").connect(hud._on_world_ping)
	assert_eq(ComponentManager.of(host).event(&"ping").get_connections().size(), 2)
	assert_eq(WorldEvents.event(&"ping").get_connections().size(), 2)
	hud.free()
	assert_eq(ComponentManager.of(host).event(&"ping").get_connections().size(), 0,
			"its method and its lambda")
	assert_eq(WorldEvents.event(&"ping").get_connections().size(), 0)


func test_world_events_hear_every_host() -> void:
	world_heard.clear()
	var first: Node3D = make_host()
	var second: Node3D = make_host()
	WorldEvents.event(&"ping").connect(_on_world_ping)
	var ctx := EffectContext.new(null, second)
	ComponentManager.notify(first, &"ping")
	ComponentManager.notify(second, &"ping", ctx)
	ComponentManager.notify(second, &"pong", ctx)
	assert_eq(world_heard.size(), 2, "once for each host that sent it")
	assert_eq(world_heard[0][0], first)
	assert_eq(world_heard[1], [second, ctx])
	WorldEvents.event(&"ping").disconnect(_on_world_ping)
	ComponentManager.notify(first, &"ping")
	assert_eq(world_heard.size(), 2)


func test_world_events_drop_freed_listeners() -> void:
	var host: Node3D = make_host()
	var quest := Listener.new()
	WorldEvents.event(&"ping").connect(quest._on_world_ping)
	ComponentManager.notify(host, &"ping")
	assert_eq(quest.heard, [host])
	quest.free()
	ComponentManager.notify(host, &"ping")
	pass_test("no error after the listener is gone")


func test_any_death_can_be_counted_from_one_place() -> void:
	var deaths: Array = []
	var count := func(who: Node, _ctx: EffectContext) -> void: deaths.append(who)
	WorldEvents.event(&"died").connect(count)
	var grunt: Node3D = make_host([Health.new()])
	var brute: Node3D = make_host([Health.new()])
	Health.find_on(brute).change(-500.0)
	Health.find_on(grunt).change(-500.0)
	assert_eq(deaths, [brute, grunt])
	WorldEvents.event(&"died").disconnect(count)


func _on_world_ping(host: Node, ctx: EffectContext) -> void:
	world_heard.append([host, ctx])


## Remembers the events it heard, in order.
class Listener:
	extends Component

	var heard: Array = []
	var log: Array = []
	var other: Node

	func _start() -> void:
		on(&"ping", _on_ping)
		listen(manager.event_sent, _on_any)
		if other:
			on(&"ping", _on_other_ping, other)

	func _on_ping(ctx: EffectContext) -> void:
		heard.append(ctx)

	func _on_other_ping(_ctx: EffectContext) -> void:
		heard.append(&"other")

	func _on_world_ping(host: Node, _ctx: EffectContext) -> void:
		heard.append(host)

	## Subscribes lambdas that use this object, the way a HUD script might.
	func watch(host: Node) -> void:
		ComponentManager.of(host).event(&"ping").connect(
				func(_ctx: EffectContext) -> void: heard.append(&"lambda"))
		WorldEvents.event(&"ping").connect(func(_host: Node, _ctx: EffectContext) -> void:
			heard.append(&"world lambda"))

	func _on_any(event: StringName, _ctx: EffectContext) -> void:
		if event == &"ordered":
			log.append(&"every event")
