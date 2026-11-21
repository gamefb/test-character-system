# Recipes

Short answers to "how do I…". Every resource named here has a working copy in
`character_system/examples/`: duplicate it (right-click > Duplicate) and change the copy.
For any class, press **F1** in Godot and search its name for the full reference.

## Make a character

1. New scene with a **CharacterBody3D** root, a **CollisionShape3D** (capsule) and a mesh.
2. Add a **ComponentManager**, then the components you want, in any order: `Statuses`,
   `Health`, a brain (`PlayerBrain` or `AIBrain`), `Movement`, `Faction`, `Inventory`,
   `Equipment`, `WeaponSwitch`, `Abilities`.
3. Fix any yellow warning triangles in the Scene dock. They name what's missing.

A component without what it needs waits instead of crashing, and starts once it's added.

## Make a status

New Resource > **StatusData**. The fields you'll use most:

| Want | Set |
| --- | --- |
| Damage over time | `duration` 4, `tick_interval` 1, `on_tick` = DamageEffect |
| A stat change while active | `modifiers` = StatModifier, e.g. `move_speed`, mul 1.5 |
| React to hits | `triggers` = StatusTrigger on `taking_damage`, `took_damage`, ... |
| Stack up | `stacking` STACK, `max_stacks` 3 |
| A passive (no time limit) | `duration` 0 |

Give it at least one tag, such as `fire`. Tags are how immunities and conditions find it.
Examples: `statuses/burning.tres`, `poisoned.tres`, `haste.tres`, `thorns.tres`.

## Make something immune

Immunity goes on the thing that protects. Put the tags it keeps out in `immune_to`:

- **A trait:** a StatusData with duration 0 and `immune_to = poison`, added to the
  character's **Statuses > Innate**. See `traits/undead.tres`.
- **A temporary state:** Wet has `immune_to = fire`, plus `removes_tags = fire` to put out
  burning it lands on. See `statuses/wet.tres`.
- **From an item:** see the cloak, below.

`immune_to` only keeps out new statuses. Add `removes_tags` too to clear current ones.

## Make an item that gives a passive

1. New scene: a **Node3D** root, a **ComponentManager**, a **GrantStatuses**. Put the passive
   in GrantStatuses > Statuses.
2. New Resource > **ItemData**: set `slot` (e.g. `cloak`) and `scene` to that scene.
3. On the character, add the slot to **Equipment > Sockets**, pointing at a Node3D.

Equip it with `(Component.of(player, Equipment) as Equipment).equip(ItemInstance.new(cloak_data))`.
The item goes into the Inventory too, and is unequipped if it ever leaves it.
See `items/fireproof_cloak.tres`.

## Make a weapon

The item scene gets a **Trigger** (fire rate), a **Magazine** (capacity, ammo item) and a
**Hitscan** (range, `effects`). Put a DamageEffect in the effects. For bonus damage against
wet targets, add a second DamageEffect with a HasTagCondition (`wet`).
See `items/rifle.tres` and `items/flare_gun.tres`.

## Carry several weapons

Add a **WeaponSwitch** to the character (it needs a brain, Inventory and Equipment) and add
`next_weapon` and `previous_weapon` to the Input Map. Weapons picked up go into the
Inventory; the first one is drawn, the rest wait. From code:

```gdscript
var switch := Component.of(player, WeaponSwitch) as WeaponSwitch
switch.cycle(1)  # Next weapon; -1 = previous.
switch.select(0)  # The first weapon picked up.
switch.holster()  # Put it away.
```

## Pick up and drop items

```gdscript
var bag := Component.of(player, Inventory) as Inventory
bag.add(ammo_data, 30)  # Fills existing stacks first.
bag.add_instance(dropped_rifle)  # Keeps that copy's rounds.
bag.remove_instance(bag.first(rifle_data))  # Drops it; it's unequipped automatically.
```

## Make a zone

Instance one of `examples/zones/`, or build one: an **EffectZone** (Area3D) with a
CollisionShape3D.

- **While inside** (water, healing pad, ward circle): set `status_while_inside` to a
  status with duration 0. It ends when the body leaves.
- **Once on entry** (fire patch, poison bog): put an ApplyStatusEffect in `on_enter`.

## Make an ability

New Resource > **AbilityData**: `cooldown` and `effects`. Leave `targeting` empty to affect
the user. On the character, add it to **Abilities > Slots** under an action, e.g.
`secondary`. See `abilities/second_wind.tres`.

## React to a button

Read the character's brain the way Godot's input docs read `Input`, in `_process()` or
`_physics_process()`. It works the same whether a player or an AI is pressing:

```gdscript
func _physics_process(_delta: float) -> void:
	var brain := find(Brain) as Brain
	if brain.is_action_just_pressed(&"jump"):  # Once per press.
		pass
	if brain.is_action_pressed(&"primary"):  # Every frame it's held.
		pass
```

Add the action to the Input Map and to `PlayerBrain.ACTIONS`. AI presses buttons with
`brain.press(&"primary")` and lets go with `brain.release(&"primary")`.

## React to an event

Events are sent to every running component. Status triggers only react to events that
carry a context (`ctx`):

| Event | When | Status triggers |
| --- | --- | --- |
| `started` | The character has finished starting | No |
| `dealing_damage`, `taking_damage` | Before a hit lands; change `ctx.amount` with ModifyAmountEffect | Yes |
| `dealt_damage`, `took_damage` | After a hit lands | Yes |
| `died` | Health reached 0 | When something dealt the killing blow |
| `inventory_changed` | Something was added to or removed from the Inventory | No |

In your own component, override `_on_event(event, ctx)`. Send your own with
`ComponentManager.notify(node, &"my_event", ctx)`; pass a context if statuses should react.

## Write your own effect, condition or component

```gdscript
# With a class_name, it appears in the effect list in the Inspector.
class_name SlowEffect
extends Effect

@export var seconds: float = 2.0


func _execute(ctx: EffectContext) -> void:
	var statuses := Component.of(ctx.target, Statuses) as Statuses
	if statuses:  # The target may not have one.
		pass  # E.g. statuses.add(slowed).
```

- **Condition:** extend `Condition` and override `_test(node) -> bool`.
- **Component:** extend `Component`. Do your setup in `_start()` (not `_ready()`), list what
  you need in `_requires()`, and numbers statuses may change in `_stats()`. Its
  `_process()` only runs while it's running. Press F1 on `Component` for an example.

## Find out what's going on

- **Run the game and open the Remote tab** in the Scene dock. Click a character's
  **Statuses** to see `active`: each status it has, with its stacks and time left.
- **A status didn't land?** Connect to `Statuses.refused`. It fires with the status that
  was turned away, by an immunity or a failed `apply_conditions`.
- **A component does nothing?** Check the Output panel for "can't start: it needs …".
- `ComponentManager.stat_of(node, &"move_speed")` prints any stat's current value.
