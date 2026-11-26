extends GutTest
## Holds: what a component gives with hold_modifier() or hold_status() is taken back when it
## lets go or stops, and never more than it gave.

var character: Node3D
var manager: ComponentManager
var statuses: Statuses
var part: Part


func before_each() -> void:
	character = Node3D.new()
	part = Part.new()
	for node: Node in [ComponentManager.new(), Statuses.new(), part]:
		character.add_child(node)
	add_child_autofree(character)
	manager = ComponentManager.of(character)
	statuses = Statuses.find_on(character)
	manager.set_base(&"power", 10.0)


func boost(add: float) -> StatModifier:
	var m := StatModifier.new()
	m.stat = &"power"
	m.add = add
	return m


func passive(tags: Array[StringName] = []) -> StatusData:
	var s := StatusData.new()
	s.tags = tags
	return s


func test_a_held_modifier_counts_once_however_often_it_is_asked_for() -> void:
	var m: StatModifier = boost(5.0)
	part.hold_modifier(m)
	part.hold_modifier(m)
	assert_eq(manager.stat(&"power"), 15.0)
	assert_eq(manager.modifiers_of(&"power")[0].source, part, "the component is behind it")
	part.hold_modifier(m, false)
	assert_eq(manager.stat(&"power"), 10.0)
	part.hold_modifier(m, false)
	assert_eq(manager.stat(&"power"), 10.0, "letting go twice takes nothing more off")


func test_a_held_status_stays_until_it_is_let_go() -> void:
	var blessed: StatusData = passive()
	assert_true(part.hold_status(blessed))
	assert_true(part.hold_status(blessed), "still held")
	assert_eq(statuses.active[blessed].holds, 1, "asked for twice, held once")
	assert_false(part.hold_status(blessed, false))
	assert_false(statuses.active.has(blessed))
	assert_false(part.hold_status(null), "no status set: nothing to hold")


func test_stopping_takes_back_everything_held() -> void:
	var blessed: StatusData = passive()
	part.hold_modifier(boost(5.0))
	part.hold_status(blessed)
	part.free()
	assert_eq(manager.stat(&"power"), 10.0)
	assert_false(statuses.active.has(blessed))


func test_a_refused_status_is_not_held_and_nobody_elses_hold_is_dropped() -> void:
	var cursed: StatusData = passive([&"curse"])
	statuses.add(cursed)  # Somebody else holds it already.
	var warded: StatusData = passive()
	warded.immune_to = [&"curse"]
	statuses.add(warded)
	watch_signals(statuses)
	assert_false(part.hold_status(cursed), "refused: the character is immune now")
	assert_false(part.hold_status(cursed))
	assert_signal_emit_count(statuses, "refused", 1, "asked for once, not on every call")
	part.hold_status(cursed, false)
	part.free()
	assert_eq(statuses.active[cursed].holds, 1, "the other hold is still there")


func test_an_items_holds_go_to_its_wielder() -> void:
	var item := Node3D.new()
	var item_part := ItemPart.new()
	item_part.wielder = character
	for node: Node in [ComponentManager.new(), item_part]:
		item.add_child(node)
	character.add_child(item)
	var blessed: StatusData = passive()
	item_part.hold_modifier(boost(5.0))
	item_part.hold_status(blessed)
	assert_eq(manager.stat(&"power"), 15.0)
	assert_true(statuses.active.has(blessed))
	assert_eq(ComponentManager.of(item).modifiers_of(&"power").size(), 0, "not on the item")
	item.free()  # Unequipped.
	assert_eq(manager.stat(&"power"), 10.0)
	assert_false(statuses.active.has(blessed))


func test_nothing_is_held_while_waiting_to_start() -> void:
	var waiting := Waiting.new()
	character.add_child(waiting)
	if has_method(&"assert_push_error"):  # GUT 9.5 or later.
		call(&"assert_push_error", "can't start")
	waiting.hold_modifier(boost(5.0))
	assert_false(waiting.hold_status(passive()))
	assert_eq(manager.stat(&"power"), 10.0, "a part that never starts would never take it back")


func test_a_wielder_that_was_freed_first_is_let_go_of_quietly() -> void:
	var other := Node3D.new()
	other.add_child(ComponentManager.new())
	add_child(other)
	var item := Node3D.new()
	var item_part := ItemPart.new()
	item_part.wielder = other
	for node: Node in [ComponentManager.new(), item_part]:
		item.add_child(node)
	add_child(item)
	var first: StatModifier = boost(5.0)
	item_part.hold_modifier(first)
	item_part.hold_modifier(boost(1.0))
	other.free()
	item_part.hold_modifier(first, false)
	item.free()  # Lets go of the second.
	pass_test("neither is an error")


## Has nothing of its own: the tests call its holds from outside.
class Part extends Component:
	func _start() -> void:
		pass


class Waiting extends Component:
	func _requires() -> Array[Script]:
		return [Health]


## The same, inside an item.
class ItemPart extends ItemComponent:
	func _start() -> void:
		pass
