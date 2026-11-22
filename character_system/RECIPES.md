# Recipes

Short answers to "how do I…". Every resource named here has a working copy in
`character_system/examples/`: duplicate it (right-click > Duplicate) and change the copy.
For any class, press **F1** in Godot and search its name for the full reference. New to the
system? The Quick start page of the documentation builds a whole level, step by step.

## Characters

### Make a character

1. New scene with a **CharacterBody3D** root, a **CollisionShape3D** (capsule) and a mesh.
2. Add a **ComponentManager**, then the components you want, in any order: `Statuses`,
   `Health`, a brain (`PlayerBrain` or `AIBrain`), `CharacterMotor`, `Faction`, `Inventory`,
   `Equipment`, `WeaponSwitch`, `Abilities`.
3. Add a **WalkMode** and an **AirMode** as children of the `CharacterMotor`, so the character
   can walk, jump and fall.
4. A player needs a **Camera3D** and an AI a **NavigationAgent3D** somewhere under the
   character. The brain finds it by itself.
5. Fix any yellow warning triangles in the Scene dock. They name what's missing.

A component without what it needs waits instead of crashing, and starts once it's added.

### Make an enemy that attacks

1. Make a character with an **AIBrain** as its brain and a **NavigationAgent3D**, a
   **CharacterMotor** (with a WalkMode and an AirMode under it), a **Faction** and the example
   **AttackNearest**
   (`examples/scripts/attack_nearest.gd`) beside it.
2. Set its **Faction > Team** to `enemy` and **Hostile To** to `player`. Give the player a
   Faction with the team `player`.
3. Give it a weapon as for a player: a **Node3D** named Hand in front of it, **Equipment >
   Sockets** with `weapon` pointing at `../Hand`, an **Inventory** holding a rifle, and a
   **WeaponSwitch** to draw it.
4. Put the floor under a **NavigationRegion3D** and press **Bake NavigationMesh** in its
   toolbar, so the AI can find a path. Set the NavigationAgent3D's **Path Height Offset** to
   0.5, the height of a default bake.

AttackNearest picks the nearest `player` every half second and fires while it's within 15 m.

### Change the double jump

The **AirMode** under the `CharacterMotor` already double jumps: pressing jump in the air jumps
again, and taking off refills it. `Air Jumps` sets how many (2 for a triple jump, 0 for none).

To grant it with an item or a status instead, set `Air Jumps` to 0 and give the status a
`StatModifier` on `air_jumps` with add 1. A rooted status can take it away with mul 0.

### Add a dash

Add a **DashMove** as a child of the `CharacterMotor`, and a `dash` action to the Input Map and
to **PlayerBrain > Extra Actions**. `Speed`, `Duration` and `Cooldown` are in the Inspector.

### Add a new way to move

Gliding, wall slides, swimming and climbing go under the `CharacterMotor` as a movement mode
(a new way of moving that takes over) or a layered move (extra movement on top, for a while).
Copy `examples/scripts/wall_slide_mode.gd` or `examples/scripts/glide_move.gd`, and add your
copy as a child of the motor. The Extending page explains both.

### Add your own input action

Add the action in Project Settings > Input Map, then add its name to **PlayerBrain > Extra
Actions**. Components read it from the brain (see "React to a button"), and an AI presses it
with `brain.press(&"my_action")`.

## Statuses

### Make a status

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

From code: `(Component.of(enemy, Statuses) as Statuses).add(burning, player)`, where
`burning` is the loaded StatusData and `player` caused it.

### Make something immune

Immunity goes on the thing that protects. Put the tags it keeps out in `immune_to`:

- **A trait:** a StatusData with duration 0 and `immune_to = poison`, added to the
  character's **Statuses > Innate**. See `traits/undead.tres`.
- **A temporary state:** Wet has `immune_to = fire`, plus `removes_tags = fire` to put out
  burning it lands on. See `statuses/wet.tres`.
- **From an item:** see "Make an item that gives a passive", below.

`immune_to` only keeps out new statuses. Add `removes_tags` too to clear current ones.

### Make a status that changes damage

A StatusTrigger with a **ModifyAmountEffect** changes a hit before it lands:

- **A shield:** trigger on `taking_damage`, ModifyAmountEffect with mul 0.5. Turn on
  **React To Statuses** so it halves burn and poison ticks too. See `statuses/warded.tres`.
- **A damage buff:** trigger on `dealing_damage`, ModifyAmountEffect with mul 1.5.
- **A bonus against some targets:** the damage buff, with **Affects Other** on and a condition
  on the ModifyAmountEffect, such as a HasTagCondition (`wet`). Affects Other makes the
  condition look at the victim instead of the attacker.

### Make a zone

Instance one of `examples/zones/`, or build one: an **EffectZone** (Area3D) with a
CollisionShape3D.

- **While inside** (water, healing pad, ward circle): set `status_while_inside` to a
  status with duration 0. It ends when the body leaves.
- **Once on entry** (fire patch, poison bog): put an ApplyStatusEffect in `on_enter`.

## Items

### Make an item that gives a passive

1. New scene: a **Node3D** root, a **ComponentManager**, a **GrantStatuses**. Put the passive
   in GrantStatuses > Statuses.
2. New Resource > **ItemData**: set `slot` (e.g. `cloak`) and `scene` to that scene.
3. On the character, add the slot to **Equipment > Sockets**, pointing at a Node3D.

Equip it with `(Component.of(player, Equipment) as Equipment).equip(ItemInstance.new(cloak_data))`.
The item goes into the Inventory too, and is unequipped if it ever leaves it.
See `items/fireproof_cloak.tres`.

### Make a weapon

1. New scene: a **Node3D** root for the model, a **ComponentManager**, a **Trigger** (fire
   rate), a **Magazine** (capacity, ammo item) and a **Hitscan** (range, `effects`). Put a
   DamageEffect in the effects. For bonus damage against wet targets, add a second
   DamageEffect with a HasTagCondition (`wet`).
2. New Resource > **ItemData**: set `slot` to `weapon` and `scene` to that scene.
3. On the character, add `weapon` to **Equipment > Sockets**, pointing at a Node3D such as a
   hand. The path starts from the Equipment node, e.g. `../Hand`.

See `items/rifle.tres` and `items/flare_gun.tres`.

### Make a melee weapon

As for a weapon, but with a **MeleeSweep** instead of the Magazine and Hitscan. Set its
**Shape** to a BoxShape3D about a metre across and put the DamageEffect in its effects. Each
click swings once and hits everything in the box in front of the item.

### Carry several weapons

Add a **WeaponSwitch** to the character (it needs a brain, Inventory and Equipment) and add
`next_weapon` and `previous_weapon` to the Input Map. Weapons picked up go into the
Inventory; the first one is drawn, the rest wait. From code:

```gdscript
var switch := Component.of(player, WeaponSwitch) as WeaponSwitch
switch.cycle(1)  # Next weapon; -1 = previous.
switch.select(0)  # The first weapon picked up.
switch.holster()  # Put it away.
```

### Pick up and drop items

```gdscript
var bag := Component.of(player, Inventory) as Inventory
bag.add(ammo_data, 30)  # Fills existing stacks first.
bag.add_instance(dropped_rifle)  # Keeps that copy's rounds.
bag.remove_instance(bag.first(rifle_data))  # Drops it; it's unequipped automatically.
```

## Abilities

### Make an ability

New Resource > **AbilityData**: `cooldown` and `effects`. Leave `targeting` empty to affect
the user. On the character, add it to **Abilities > Slots** under an action, e.g.
`secondary`. See `abilities/second_wind.tres`.

### Make an ability that hits everyone nearby

Set the ability's **Targeting** to a new **RadiusTargeting** and choose its radius. With
**Hostile Only** on, it only reaches what the user's Faction fights; for a party heal, turn it
off and **Include User** on. A shockwave is a RadiusTargeting with a DamageEffect and a
KnockbackEffect.

## Your own code

### React to a button

Read the character's brain the way Godot's input docs read `Input`, in `_process()` or
`_physics_process()`. It works the same whether a player or an AI is pressing:

```gdscript
func _physics_process(_delta: float) -> void:
	var brain := find(Brain) as Brain
	if brain.is_action_just_pressed(&"interact"):  # Once per press.
		pass
	if brain.is_action_pressed(&"primary"):  # Every frame it's held.
		pass
```

For your own action, add it to the Input Map and to **PlayerBrain > Extra Actions**. AI
presses buttons with `brain.press(&"primary")` and lets go with `brain.release(&"primary")`.

### React to an event

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
`ComponentManager.notify(node, &"my_event")`, and status triggers react to it too. To say who
caused it, pass a context as well:
`ComponentManager.notify(node, &"my_event", EffectContext.new(who, node))`.

### Add a stat or a damage type

- **A stat:** return it from your component's `_stats()`, e.g. `{ &"max_stamina": max_stamina }`,
  and read it with `stat(&"max_stamina")`. Statuses change it with a StatModifier of that name.
- **A damage type:** type any name in a DamageEffect's `type`, e.g. `lightning`. Resistance to
  it is the `resist_lightning` stat: add `lightning` to **Health > Resistances**, or give a
  status a StatModifier on `resist_lightning`.

### Write your own effect, condition or component

The Extending the system page of the documentation has a complete, tested example of each,
also in `examples/scripts/`. In short:

- **Effect:** extend `Effect` and override `_execute(ctx)`. The target may have none of the
  components you need, so check for null.
- **Condition:** extend `Condition` and override `_test(node) -> bool`, or `check(ctx)` to
  compare both sides, as `IsHostileCondition` does.
- **Component:** extend `Component`. Do your setup in `_start()` (not `_ready()`), list what
  you need in `_requires()`, and numbers statuses may change in `_stats()`. Its
  `_process()` only runs while it's running. See `examples/scripts/stamina.gd`.
- **Item component:** extend `ItemComponent`. `wielder`, `item` and `brain` are ready in
  `_start()`, and anything it changes on the wielder must be undone in `_stop()`. See
  `examples/scripts/scope.gd`.

A complete effect, for a lifesteal status:

```gdscript
# With a class_name, it appears in the effect list in the Inspector.
class_name LifestealEffect
extends Effect

## Share of the hit healed back, e.g. 0.25 for a quarter.
@export var share: float = 0.25


# Put it in a status trigger on dealt_damage: the trigger's target is the holder, who just
# dealt the hit, and ctx.cause is that hit.
func _execute(ctx: EffectContext) -> void:
	var health := Component.of(ctx.target, Health) as Health
	if health and ctx.cause:  # The target may have no Health.
		health.change(maxf(ctx.cause.amount, 0.0) * share * ctx.magnitude, ctx)
```

## Show it on screen

### Show health, statuses, ammo and cooldowns

`examples/scripts/character_hud.gd` (**CharacterHud**) does all four. Attach it to a Control,
add a ProgressBar named HealthBar and Labels named Statuses, Ammo and Cooldown under it, and set
**Character** to the player and **Ability** to one of its abilities. To build your own, read
these:

| Show | Read |
| --- | --- |
| Health bar | `Health.changed(current, maximum)`; `current` and `maximum()` for the first draw |
| Status bar | `Statuses.changed`, then `Statuses.active`: each StatusData's `display_name` and `icon`, and its `stacks` and `time_left` |
| Ammo | `Component.of(gear.node_in(&"weapon"), Magazine)`, then its `rounds` and `capacity` |
| Cooldown | `Abilities.cooldown_left(ability)` |
| Stamina | the example Stamina's `changed(current, maximum)` |

## Find out what's going on

- **Run the game and open the Remote tab** in the Scene dock. Click a character's
  **Statuses** to see `active`: each status it has, with its stacks and time left.
- **A status didn't land?** Connect to `Statuses.refused`. It fires with the status that
  was turned away, by an immunity or a failed `apply_conditions`.
- **A component does nothing?** Check the Output panel for "can't start: it needs …".
- `ComponentManager.stat_of(node, &"move_speed")` prints any stat's current value.
