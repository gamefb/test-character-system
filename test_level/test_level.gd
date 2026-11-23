extends Node3D
## A level with every part of the character system in it. Open [code]test_level.tscn[/code]
## and press F6 to play.
##
## The level itself is built from the system's nodes and resources in the Inspector. This
## script only does what a game would do around them: it adds the input actions, equips what
## the player picks up, uses potions and grenades from the bag, shows numbers on screen, and
## brings the dead back after a moment.

## Keys for the actions the level uses, added to the Input Map if the project lacks them.
const KEYS: Dictionary[StringName, Key] = {
	&"forward": KEY_W, &"back": KEY_S, &"left": KEY_A, &"right": KEY_D, &"jump": KEY_SPACE,
	&"reload": KEY_R, &"sprint": KEY_SHIFT, &"dash": KEY_F, &"next_weapon": KEY_E,
	&"previous_weapon": KEY_Q, &"interact": KEY_T, &"use_health_potion": KEY_H,
	&"use_mana_potion": KEY_J, &"throw_grenade": KEY_G,
	&"ability_1": KEY_1, &"ability_2": KEY_2, &"ability_3": KEY_3, &"ability_4": KEY_4,
}
const MOUSE: Dictionary[StringName, MouseButton] = {
	&"primary": MOUSE_BUTTON_LEFT, &"secondary": MOUSE_BUTTON_RIGHT,
}
const HELP := """WASD move   Space jump, again in the air, hold to glide   Shift sprint   F dash
Left mouse fire   Right mouse zoom or staff spell   R reload   E / Q switch weapon
1 Second wind   2 Sprint   3 Fireball   4 Shockwave   Esc free the mouse
H health potion   J mana potion   G throw a grenade"""
## Seconds before a dead character or dummy in the "respawns" group stands back up.
const RESPAWN_TIME := 4.0

## Items used straight from the bag when their action is pressed.
@export var quick_items: Dictionary[StringName, ItemData] = {}

@onready var _player: Node3D = $Player
@onready var _info: Label = $Hud/CharacterHud/Info


func _enter_tree() -> void:
	# Before the player starts, because PlayerBrain looks its actions up then.
	for action: StringName in KEYS:
		var key := InputEventKey.new()
		key.physical_keycode = KEYS[action]
		_add_action(action, key)
	for action: StringName in MOUSE:
		var button := InputEventMouseButton.new()
		button.button_index = MOUSE[action]
		_add_action(action, button)


func _ready() -> void:
	($Hud/CharacterHud/Help as Label).text = HELP
	for pickup: ItemPickup in find_children("*", "ItemPickup", true, false):
		pickup.picked_up.connect(_on_picked_up.bind(pickup.item))
	WorldEvents.event(&"took_damage").connect(_on_took_damage)
	WorldEvents.event(&"died").connect(_on_died)
	if "--self-test" in OS.get_cmdline_user_args():
		add_child(preload("self_test.gd").new())


func _process(_delta: float) -> void:
	var brain := Component.of(_player, Brain) as Brain
	for action: StringName in quick_items:
		if brain.is_action_just_pressed(action):
			(Component.of(_player, Inventory) as Inventory).use(quick_items[action])
	for soldier: Node3D in get_tree().get_nodes_in_group(&"faces_aim"):
		var aim: Vector3 = (Component.of(soldier, Brain) as Brain).aim_point
		aim.y = soldier.global_position.y
		if aim.distance_to(soldier.global_position) > 0.1:
			soldier.look_at(aim)
	_info.text = describe(_player)


## Everything worth knowing about [param character], as text for the screen.
func describe(character: Node) -> String:
	var lines: PackedStringArray = []
	var pools: PackedStringArray = []
	for p: Pool in ComponentManager.of(character).find_all(Pool):
		pools.append("%s %d/%d" % [String(p.pool).capitalize(), p.current, p.maximum()])
	var stamina := Component.of(character, Stamina) as Stamina
	pools.append("Stamina %d/%d" % [stamina.current, stamina.stat(&"max_stamina")])
	lines.append("   ".join(pools))
	var weapon: ItemInstance = (Component.of(character, WeaponSwitch) as WeaponSwitch).current()
	lines.append("Weapon: %s" % (weapon.data.display_name if weapon else "none"))
	var abilities := Component.of(character, Abilities) as Abilities
	var spells: PackedStringArray = []
	for action: StringName in abilities.slots:
		var ability: AbilityData = abilities.slots[action]
		var wait: float = abilities.cooldown_left(ability)
		var state: String = "casting" if abilities.casting == ability else (
				"ready" if wait == 0.0 else "%.1f s" % wait)
		spells.append("%s: %s" % [ability.display_name, state])
	lines.append("   ".join(spells))
	var gear := Component.of(character, Equipment) as Equipment
	var carried: PackedStringArray = []
	for item: ItemInstance in (Component.of(character, Inventory) as Inventory).items:
		var worn: String = " (on)" if item in gear.equipped.values() else ""
		carried.append("%s%s%s" % [item.data.display_name,
				" ×%d" % item.count if item.count > 1 else "", worn])
	lines.append("Bag: %s" % (", ".join(carried) if carried else "empty"))
	var numbers: PackedStringArray = []
	for stat_name: StringName in [&"max_health", &"move_speed", &"strength", &"spell_power",
			&"crit_chance", &"level"]:
		numbers.append("%s %s" % [String(stat_name).capitalize(),
				snappedf(ComponentManager.stat_of(character, stat_name), 0.01)])
	lines.append("   ".join(numbers))
	return "\n".join(lines)


func _add_action(action: StringName, event: InputEvent) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
		InputMap.action_add_event(action, event)


# Weapons are drawn by the WeaponSwitch. Anything else with a slot is put on if it's free.
func _on_picked_up(by: Node, item: ItemData) -> void:
	var gear := Component.of(by, Equipment) as Equipment
	if gear and item.slot and item.slot != &"weapon" and not gear.equipped.has(item.slot):
		gear.equip((Component.of(by, Inventory) as Inventory).first(item))


# A number floats up from every hit in the level, whoever dealt it.
func _on_took_damage(host: Node, ctx: EffectContext) -> void:
	var number := Label3D.new()
	number.text = "%d%s%s" % [roundi(ctx.amount), " head" if ctx.has_tag(&"head") else "",
			" crit" if ctx.has_tag(&"crit") else ""]
	number.modulate = Color.ORANGE if ctx.damage_type == &"fire" else Color.WHITE
	number.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	number.no_depth_test = true
	number.font_size = 56
	number.outline_size = 12
	add_child(number)
	number.global_position = ctx.hit_position() if ctx.position.is_finite() else (
			(host as Node3D).global_position + Vector3.UP * 1.9)
	var tween: Tween = number.create_tween()
	tween.tween_property(number, ^"position:y", number.position.y + 1.0, 0.7)
	tween.tween_callback(number.queue_free)


func _on_died(host: Node, _ctx: EffectContext) -> void:
	if host.is_in_group(&"respawns"):
		await get_tree().create_timer(RESPAWN_TIME).timeout
		var health := Component.of(host, Health) as Health  # Null if it was freed meanwhile.
		if health:
			health.revive()
