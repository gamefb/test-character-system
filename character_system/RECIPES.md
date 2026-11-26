# Recipes

Short answers to "how do I…". Every resource named here has a working copy in
`character_system/starter_pack/`: duplicate it (right-click > Duplicate) and change the copy.
For any class, press **F1** in Godot and search its name for the full reference. New to the
system? The Quick start page of the documentation builds a whole level, step by step. To
try everything here in play, open `test_level/test_level.tscn` and press F6.

A field that holds a name (a stat, a pool, an event, a tag, something to block) opens a list
of the names the project already has. Pick one, or type a new one.

## Characters

### Make a character

1. New scene with a **CharacterBody3D** root, a **CollisionShape3D** (capsule) and a mesh.
2. Add a **ComponentManager**, then the components you want, in any order: `Statuses`,
   `Health`, a brain (`PlayerBrain` or `AIBrain`), `CharacterMotor`, `Faction`, `Inventory`,
   `Equipment`, `WeaponSwitch`, `Abilities`, and a `Pool` for each of mana, stamina or a
   shield.
3. Add a **WalkMode** and an **AirMode** as children of the `CharacterMotor`, so the character
   can walk, jump and fall.
4. A player needs a **Camera3D** and an AI a **NavigationAgent3D** somewhere under the
   character. The brain finds it by itself. The player aims at whatever the middle of the
   camera's view is on, so a crosshair goes in the centre of the screen; weapons shoot from
   where they are held and still hit that point.
5. Fix any yellow warning triangles in the Scene dock. They name what's missing.

A component without what it needs waits instead of crashing, and starts once it's added.
`starter_pack/characters/mage.tscn` is a small character to look at: health, stats of her own, a
mana pool, a shield and a Fireball.

### Give a character its own stats

Strength, level, crit chance, spell power: select the character's **ComponentManager** and list
each stat and its value under **Stats**. No script and no extra node is needed. A listed stat
works everywhere stats do: statuses and gear change it with a StatModifier, effects scale with
it (see "Make damage scale with a stat"), and code reads it with `stat(&"strength")` or
`ComponentManager.stat_of(node, &"strength")`.

```gdscript
var manager := ComponentManager.of(player)
manager.add_base(&"level", 1)  # Level up: everything that scales with level follows.
```

### Add mana, stamina or a shield

Add a **Pool** and set **Pool** to its name, e.g. `mana`. `Max Value` is how much it holds,
`Regen` how much comes back each second, and `Regen Delay` how long after spending before
that starts. A character can have several pools.

- **Spend it** with an ability's **Costs** (see "Make a spell"), or from code:
  `Pool.named(player, &"mana").spend(20.0)` returns false if there isn't enough.
- **Refill or drain it** with a **ChangePoolEffect**, e.g. in a potion or a status tick.
- **Buff it** with a StatModifier on `max_mana` or `mana_regen` (the pool's name, with
  `max_` in front or `_regen` behind).
- **Make it a shield:** turn on **Absorbs Damage**. Damage then comes out of the pool first,
  and only what's left reaches Health. With `Regen` 10 and `Regen Delay` 3 it recharges once
  the character has gone 3 seconds without being hit.
- **Rage that builds up:** turn **Starts Full** off and give `Regen` a negative number, so it
  fades.
- **Something happens when it runs out:** set **Status While Empty**. The character has that
  status for as long as the pool is empty: an Exhausted status that blocks `movement` on a
  stamina pool, say. Death works this way.
- **Sprint on stamina:** a Pool called `stamina`, and the example **Sprint** component
  (`starter_pack/scripts/sprint.gd`) beside it, which spends from the pool while a button is
  held.

**Health is a pool too**, named `health`. So `max_health` and `health_regen` are stats, an
ability can cost health, and a bar that shows a pool shows health. Its settings are on the
**Health** component: **Max Value**, **Regen**, **Resistances** and **Death Status**.

### Stun, silence, root or disarm a character

Each is a status that lists what it stops in **Blocks**, and no code. Everything that can be
stopped answers to a name, and a status that lists the name stops it:

| Want | Put in the status's Blocks | Example |
| --- | --- | --- |
| Stun: can't move, shoot or cast | `everything` (the Brain answers to it) | `statuses/stunned.tres` |
| Root: can't walk, jump or dash | `movement` (the CharacterMotor) | `statuses/rooted.tres` |
| Disarm: can't fire or swing | `weapons` (every Trigger) | |
| Daze: no abilities at all | `abilities` (every ability) | |
| Silence: no spells, other abilities still work | `spells` | `statuses/silenced.tres` |
| Invulnerable | `damage` | |
| Can't be healed | `healing` | |
| Hidden: shots pass through, AI and area abilities leave it alone | `targeting` | |

`spells` is a name of your own. Add it to **Blocked By** on the abilities that count as
spells, as `abilities/fireball.tres` does, and any status that blocks `spells` stops them.
The same works for one weapon (**Trigger > Blocked By**) or one move (a dash's **Blocked
By**). From code, `ComponentManager.of(player).block(&"everything")` does what a status
does, for a cutscene, until `unblock()`.

### Decide what death does

Death is a status too. A **Health** component gives the character its **Death Status** at
zero health and takes it back on `Health.revive()`. The default, `core/statuses/dead.tres`,
blocks `everything`, `healing` and `targeting` and ends timed statuses, so the dead can't
act or be healed, and shots pass through them.

| Want | Do |
| --- | --- |
| A boss that keeps fighting at zero for a last phase | Give it a Death Status of your own that blocks less |
| "Downed": crawling, can be revived by an ally | A status that blocks `weapons` and `abilities` and slows `move_speed`; the ally's ability calls `revive()` |
| A corpse that still blocks shots | Copy Dead without `targeting` in its Blocks |
| Nothing ever dies | Clear **Death Status**. Health then simply stops at zero; the `died` event is still sent |

The character needs a **Statuses** component for any of this.

### Make an enemy that attacks

1. Make a character with an **AIBrain** as its brain and a **NavigationAgent3D**, a
   **CharacterMotor** (with a WalkMode and an AirMode under it), a **Faction** and the example
   **AttackNearest**
   (`starter_pack/scripts/attack_nearest.gd`) beside it.
2. Set its **Faction > Team** to `enemy` and **Hostile To** to `player`. Give the player a
   Faction with the team `player`.
3. Give it a weapon as for a player: a **Node3D** named Hand in front of it, **Equipment >
   Sockets** with `weapon` pointing at `../Hand`, an **Inventory** holding a rifle, and a
   **WeaponSwitch** to draw it.
4. Put the floor under a **NavigationRegion3D** and press **Bake NavigationMesh** in its
   toolbar, so the AI can find a path. Set the NavigationAgent3D's **Path Height Offset** to
   0.5, the height of a default bake.

AttackNearest picks the nearest `player` every half second and fires while it's within 15 m.
For a weapon that charges, set its **Hold Time** to how long it should hold the button.

### Change the double jump

The **AirMode** under the `CharacterMotor` already double jumps: pressing jump in the air jumps
again, and taking off refills it. `Air Jumps` sets how many (2 for a triple jump, 0 for none).

To grant it with an item or a status instead, set `Air Jumps` to 0 and give the status a
`StatModifier` on `air_jumps` with add 1.

### Add a dash

Add a **DashMove** as a child of the `CharacterMotor`, and a `dash` action to the Input Map and
to **PlayerBrain > Extra Actions**. `Speed`, `Duration` and `Cooldown` are in the Inspector.
A stunned or rooted character can't start one, and a dash in progress ends when the status
lands: see "Stop movement with a status".

### Add a new way to move

Gliding, wall slides, swimming and climbing go under the `CharacterMotor` as a movement mode
(a new way of moving that takes over) or a layered move (extra movement on top, for a while).
Copy `starter_pack/scripts/wall_slide_mode.gd` or `starter_pack/scripts/glide_move.gd`, and add your
copy as a child of the motor. "Write your own movement mode or move" below explains how to
write one from scratch.

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

From code: `Statuses.find_on(enemy).add(burning, player)`, where
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

For a plain "20% more fire damage", give the status a StatModifier on `bonus_fire` with add
0.2: every DamageEffect adds its source's `bonus_<type>` stat as a percentage. A StatModifier
on `resist_fire` does the reverse for damage taken (1 is immune, negative is a weakness).

For anything with a condition, a StatusTrigger with a **ModifyAmountEffect** changes a hit
before it lands. It has three numbers, and the hit lands for
(amount + add) × (1 + percent) × mul, whichever status was applied first:

- **Armour:** trigger on `taking_damage`, **Add** -3.
- **A shield:** trigger on `taking_damage`, **Mul** 0.5. Turn on **React To Statuses** so it
  halves burn and poison ticks too. See `statuses/warded.tres`.
- **A damage buff:** trigger on `dealing_damage`, **Percent** 0.5. Two of them make +100%.
- **A bonus against some targets:** the damage buff, with **Affects Other** on and a
  HasTagCondition (`wet`) in the trigger's **Conditions**. Affects Other makes the condition
  look at the victim instead of the attacker.
- **Only against one damage type:** a **HitCondition** with the type in **Types**, in the
  trigger's Conditions. See `statuses/fire_ward.tres`, which halves fire and nothing else.
- **A headshot bonus:** give the head Hurtbox the tag `head`, and the trigger a
  **HitCondition** with `head` in **Tags**. See `statuses/sharpshooter.tres`.
- **Critical hits:** a **ChanceCondition** in the trigger's Conditions, **Mul** 2 and **Tag**
  `crit` on the effect. Set the condition's **Bonus Stat** to `crit_chance` and gear can
  raise the odds. See `statuses/lucky_strikes.tres`.
- **Stronger with every stack:** turn on the effect's **Per Stack**.
- **One of several conditions is enough:** put them inside an **AnyCondition**. See
  `statuses/executioner.tres`: +50% against targets that are wet or below half health.

A stat bonus can have a condition too: give the StatModifier its own **Conditions**. See
`statuses/berserk.tres`, which adds speed only while strength is 5 or more.

### Make damage or healing scale with a stat

DamageEffect, HealEffect and ChangePoolEffect each have a plain **Amount** and a **Scaling**
list. Everything in the list is added to the amount each time the effect runs:

| Want | Add to Scaling |
| --- | --- |
| 10 + 2 per point of the user's strength | **StatAmount**: stat `strength`, of SOURCE, per point 2 |
| Damage by level, on a curve | **StatAmount**: stat `level`, with a **Curve** from level 1 to the top level |
| 5% of the target's maximum health | **PoolAmount**: of TARGET, part MAXIMUM, fraction 0.05 |
| Heal 30% of missing health | **PoolAmount**: of TARGET, part MISSING, fraction 0.3 |
| More the less mana the caster has | **PoolAmount**: of SOURCE, pool `mana`, part MISSING |
| 0 to 6 extra, at random | **RandomAmount**: low 0, high 6 |
| A share of the hit that set off a trigger | **HitAmount**: see the next recipe |

The stat can be one a component owns (`max_health`) or one you listed in the
manager's Stats. A status tick's source is whoever applied the status, so a mage's burns grow with
the mage's `spell_power`. `starter_pack/projectiles/fireball.tscn` uses one, and
`statuses/bleeding.tres` takes 2% of the victim's maximum health each second.

### Make a status that reacts to hits, kills and heals

A StatusTrigger runs effects when its event happens to the holder. With **Affects Other** off
they hit the holder; with it on, the other side.

| Want | Trigger |
| --- | --- |
| Life steal | On `dealt_damage`: a HealEffect with amount 0 and a **HitAmount** (fraction 0.25) in its Scaling. See `statuses/vampiric.tres`. |
| Thorns | On `took_damage`, Affects Other: a DamageEffect. With a HitAmount it returns a share of the hit instead of a fixed number. See `statuses/thorns.tres`. |
| Heal on kill | On `killed`: a HealEffect. See `statuses/bloodlust.tres`. |
| Explode on death | On `died`: a SpawnSceneEffect with an explosion scene |
| Less healing received | On `receiving_healing`: a ModifyAmountEffect with mul 0.5 |
| A buff after each ability | On `ability_used`: an ApplyStatusEffect |

"React to an event" below lists every event.

### Stop movement with a status

Slowing goes through stats: a StatModifier on `move_speed`, `jump_velocity` or `air_jumps`, as
in `statuses/wet.tres`. To stop movement outright, put `movement` in the status's **Blocks**,
as `statuses/rooted.tres` does: the character can't steer, jump or start a move, and a move
in progress ends, but it still falls and can still be knocked back. To stop one mode or move
only, give that node a name of its own in its **Blocked By**, e.g. `flight` on a glide, and
block that name instead. A blocked mode hands back to the start mode.

### Make a zone

Instance one of `starter_pack/zones/`, or build one: an **EffectZone** (Area3D) with a
CollisionShape3D.

- **While inside** (water, healing pad, ward circle): set `status_while_inside` to a
  status with duration 0. It ends when the body leaves.
- **Once on entry** (fire patch, poison bog): put an ApplyStatusEffect in `on_enter`.

## Items

An item is up to two files:

- An **ItemData** resource (New Resource > ItemData): its name, `max_stack`, the `slot` it is
  worn in (empty for things that are only carried), and **Use Effects** for things that are
  used up.
- A **scene**, for an item that does something while worn or held: a **Node3D** root for the
  model, a **ComponentManager**, and one item component for each thing it does. Set the
  ItemData's `scene` to it. The character needs the slot in **Equipment > Sockets**, pointing
  at a Node3D such as a hand; the path starts from the Equipment node, e.g. `../Hand`.

The components combine freely, so a staff can shoot, grant a spell and add spell power.

| Item | ItemData | Scene | Example in `items/` |
| --- | --- | --- | --- |
| Gun | slot `weapon` | Trigger, Magazine, Hitscan | `rifle.tres`, `flare_gun.tres` |
| Shotgun | slot `weapon` | The same, with Pellets and Spread | `shotgun.tres` |
| Scoped rifle | slot `weapon` | A gun plus your own item component | `marksman_rifle.tres` |
| Rocket launcher | slot `weapon` | Trigger with a LaunchProjectileEffect, Magazine | `rocket_launcher.tres` |
| Bow, charged shot | slot `weapon` | Trigger with a Charge Time and a LaunchProjectileEffect | `longbow.tres` |
| Sword, axe, fists | slot `weapon` | Trigger, MeleeSweep | `sword.tres` |
| Staff that grants a spell | slot `weapon` | Grants (Abilities) | `fire_staff.tres` |
| Ring or armour with numbers | a slot of its own | Grants (Modifiers) | `ring_of_vigor.tres` |
| Cloak or amulet with a passive | a slot of its own | Grants (Statuses) | `fireproof_cloak.tres`, `ward_amulet.tres` |
| Ammo | no slot, `max_stack` | none | `rifle_ammo.tres`, `rockets.tres` |
| Potion, food, scroll | no slot, Use Effects | none | `health_potion.tres`, `mana_potion.tres` |
| Grenade, throwing knife | no slot, Use Effects | none | `grenade.tres` |
| A weapon for AI | slot `weapon` | A gun that reloads for free | `soldier_rifle.tres` |

### Make gear that changes stats

1. New scene: a **Node3D** root, a **ComponentManager**, a **Grants**. In **Modifiers**, add
   a StatModifier for each bonus.
2. New Resource > **ItemData**: set `slot` (e.g. `ring`) and `scene` to that scene.
3. On the character, add the slot to **Equipment > Sockets**, pointing at a Node3D.

| Bonus | StatModifier |
| --- | --- |
| +25 health | `max_health`, add 25 |
| 10% faster | `move_speed`, percent 0.1 |
| Armour against one damage type | `resist_physical`, add 0.2 (1 is immune) |
| 20% more fire damage | `bonus_fire`, add 0.2 |
| More mana, faster mana | `max_mana`, `mana_regen` (any Pool: `max_<pool>`, `<pool>_regen`) |
| Shorter cooldowns | `cooldown_speed`, percent 0.2 |
| A stat of your own | `strength`, `crit_chance`, or whatever the manager's Stats list |

See `items/ring_of_vigor.tres`. For loot with random numbers, put the modifiers on the copy
instead of the scene, and each copy keeps its own:

```gdscript
var ring := ItemInstance.new(ring_data)
var bonus := StatModifier.new()
bonus.stat = &"max_health"
bonus.add = randf_range(5.0, 25.0)
ring.state[&"modifiers"] = [bonus]
Inventory.find_on(player).add_instance(ring)
```

Grant a status instead (the next recipe) when the bonus should show on a status bar, grant
an immunity or react to hits.

### Make an item that gives a passive

1. New scene: a **Node3D** root, a **ComponentManager**, a **Grants**. Put the passive in
   Grants > Statuses.
2. New Resource > **ItemData**: set `slot` (e.g. `cloak`) and `scene` to that scene.
3. On the character, add the slot to **Equipment > Sockets**, pointing at a Node3D.

Any status with duration 0 works: an immunity (`items/fireproof_cloak.tres`), a shield
(`items/ward_amulet.tres`), life steal, thorns, crits. The wearer has it until the item comes
off, and two items that give the same passive keep it until both are off.

### Make a weapon

1. New scene: a **Node3D** root for the model, a **ComponentManager**, a **Trigger** (fire
   rate), a **Magazine** (capacity, ammo item) and a **Hitscan** (range, `effects`). Put a
   DamageEffect in the effects.
2. New Resource > **ItemData**: set `slot` to `weapon` and `scene` to that scene.
3. On the character, add `weapon` to **Equipment > Sockets**, pointing at a Node3D such as a
   hand.

See `items/rifle.tres`. More to set in the Inspector:

- **Automatic fire:** the Trigger's **Automatic**. **Fire Rate** is shots per second.
- **A reload that takes time:** the Magazine's **Reload Time**. **Auto Reload** reloads when
  the trigger is pulled on an empty magazine. Leave **Ammo** empty and it reloads for free,
  which suits AI: see `items/soldier_rifle.tres`.
- **A shotgun:** the Hitscan's **Pellets** and **Spread**. See `items/shotgun.tres`.
- **Set the target alight, slow it, poison it:** an ApplyStatusEffect in the effects. See
  `items/flare_gun.tres`.
- **More damage to some targets:** a second DamageEffect with a condition, such as a
  HasTagCondition (`wet`), as the rifle has.
- **A healing gun:** a HealEffect instead of the DamageEffect.
- **Damage that grows with the wielder:** a StatAmount in the DamageEffect's Scaling. See
  "Make damage or healing scale with a stat".
- **No friendly fire:** an IsHostileCondition on the DamageEffect.
- **Sparks where the shot lands:** a SpawnSceneEffect in the effects with **At** set to
  HIT_POINT. See `items/marksman_rifle.tres`.
- **Headshots:** nothing on the weapon. Give the target a Hurtbox on its head with
  **Multiplier** 2.
- **What a shot stops at:** the first body or Hurtbox on the layers in the Hitscan's
  **Collision Mask**. It passes through other areas, such as trigger volumes, and through
  characters with a status that blocks `targeting`, such as the dead.
- **Something for the shooter on each shot**, such as a status that slows them while
  firing: the Trigger's **User Effects**.

### Make ammo

New Resource > **ItemData**: leave `slot` and `scene` empty and set `max_stack`, e.g. 60. Set
the weapon's **Magazine > Ammo** to it. Reloading takes rounds from the wielder's Inventory,
and each copy of a weapon remembers how many rounds are in it. See `items/rifle_ammo.tres`.

### Make a weapon that fires projectiles

1. New scene with a **Node3D** root and the **Projectile** script on it, and a mesh under it.
   Set its `Speed`, and `Gravity Scale` for a shot that arcs. For a rocket, set
   `Blast Radius` and put a DamageEffect in `Blast Effects`; `Impact Scene` spawns an
   explosion where it lands.
2. Build the weapon as above, without the Hitscan. In the Trigger's **User Effects**, add a
   **LaunchProjectileEffect**: set its **Projectile** to that scene and put the direct hit's
   DamageEffect in its **Effects**.

The projectile leaves from the weapon, toward what the wielder is aiming at. It never hits
whoever launched it directly, but its blast reaches everyone in range. Put an
IsHostileCondition on the blast's DamageEffect to spare the shooter and allies.
See `items/rocket_launcher.tres` and `projectiles/rocket.tscn`.

### Make a melee weapon

As for a weapon, but with a **MeleeSweep** instead of the Magazine and Hitscan. Set its
**Shape** to a BoxShape3D about a metre across and put the DamageEffect in its effects. Each
click swings once and hits everything in the box in front of the item. See
`items/sword.tres`: its damage has a RandomAmount and a StatAmount of `strength`, and its
other effects knock the target back and make it bleed.

### Give a weapon a wind-up

Set **Wind Up** on its Trigger: the seconds between the click and the shot. It works on any
weapon, so a sword's backswing, a bow's draw and a rocket launcher's spin-up are the same
number. Being stunned or disarmed during the wind-up cancels the shot, and the round goes
back in the magazine. With Wind Up at 0 the weapon fires in the frame of the click.
`items/sword.tres` winds up for a quarter of a second.

### Make a swing follow the blade

Set **Active** on the MeleeSweep: the seconds the swing stays dangerous. For that long the
Shape is checked wherever the weapon is, along the path it took, and each character is hit
once. Put the weapon in a socket that an animation moves, such as a BoneAttachment3D on the
hand bone, and the swing hits what the blade passes through. With Active at 0 the shape is
checked once, at the shot.

### Make a weapon that charges

Set **Charge Time** on its Trigger: the seconds of holding for a full charge. The click then
starts the charge, and letting go fires. The rest is in the Trigger's **Charge** group:

- **Min Charge** is the share of a full charge the shot needs. Let go sooner and nothing
  fires, and the round goes back. 0 fires on any tap; 1 only fires fully charged.
- **Status While Charging** is a status the wielder has for as long as the button is held,
  such as one that slows it. Use a status with duration 0.

A stun, a disarm or putting the weapon away cancels the charge. See `items/longbow.tres`: 0.8
seconds to draw, a quarter of that to loose, and half speed while drawing.

### Decide what a charge is worth

Charging does nothing by itself: the Trigger only measures how far the charge got, from 0 to 1.
You say what it is worth, effect by effect:

| Want | Add |
| --- | --- |
| A harder hit | A **ChargeAmount** in the DamageEffect's **Scaling**: 8 damage, and 22 more at full |
| A faster arrow | A ChargeAmount in the LaunchProjectileEffect's **Speed Scaling** |
| A bigger shove | A ChargeAmount in a KnockbackEffect's **Scaling** |
| Something only a full charge does | A **ChargeCondition** in that effect's **Conditions** |
| A reward that comes late in the draw | A **Curve** on the ChargeAmount that stays low and rises at the end |

They work on the weapon's own effects and on the effects of the projectile it launches.
`projectiles/arrow.tscn` has both: its damage grows with the draw, and it makes the target
bleed only at a full one.

### Make an item that grants an ability

Add a **Grants** to the item's scene and fill in **Abilities**: an action name and an
AbilityData, as in a character's Abilities slots. The wielder (who needs an Abilities
component) has the ability while the item is equipped, and gets back whatever was in that
slot when it's unequipped. See `items/fire_staff.tres`.

### Make a potion

New Resource > **ItemData**: leave `slot` empty, set `max_stack`, and put what it does in
**Use Effects**: a HealEffect (`items/health_potion.tres`), a ChangePoolEffect for mana
(`items/mana_potion.tres`), or an ApplyStatusEffect for an elixir. Then:

```gdscript
Inventory.find_on(player).use(potion_data)  # False if none is left.
```

One is taken from the stack on each use, unless **Consumed On Use** is off.

### Make a grenade

A grenade is a potion whose effect throws something. Make a Projectile scene with
`Gravity Scale` 1, a `Blast Radius` and a short `Lifetime`; it goes off when it hits or when
the time runs out. Put a **LaunchProjectileEffect** with that scene in the ItemData's **Use
Effects**. `Inventory.use()` then throws one where the character is aiming. See
`items/grenade.tres`.

### Give an item behaviour of your own

When no built-in component does it, write one: a script that extends **ItemComponent**, added
to the item's scene like the others. It has `wielder`, `item` and the wielder's `brain`, and
runs only while the item is equipped. `starter_pack/scripts/scope.gd` is one: while the secondary
button is held it narrows the camera and slows the wielder. `items/marksman_rifle.tres` uses
it. "Write your own effect, condition or component" below has the pattern.

### Carry several weapons

Add a **WeaponSwitch** to the character (it needs a brain, Inventory and Equipment) and add
`next_weapon` and `previous_weapon` to the Input Map. Weapons picked up go into the
Inventory; the first one is drawn, the rest wait. From code:

```gdscript
var switch := WeaponSwitch.find_on(player)
switch.cycle(1)  # Next weapon; -1 = previous.
switch.select(0)  # The first weapon picked up.
switch.holster()  # Put it away.
```

### Pick up, wear and drop items

```gdscript
var bag := Inventory.find_on(player)
bag.add(ammo_data, 30)  # Fills existing stacks first.
bag.add_instance(dropped_rifle)  # Keeps that copy's rounds.
var gear := Equipment.find_on(player)
gear.equip(bag.first(ring_data))  # Put on something from the bag.
gear.unequip(&"ring")  # Take it off; it stays in the bag.
bag.remove_instance(bag.first(rifle_data))  # Drops it; it's unequipped automatically.
```

Putting an item in the bag doesn't put it on: when to equip is your game's rule. Weapons are
the exception with a WeaponSwitch, which draws the first one by itself. A pickup in the world
is an Area3D that calls `bag.add()` for the body that enters it; `ItemPickup` in
`test_level/item_pickup.gd` is one to copy, and `test_level/test_level.gd` puts on
whatever has a free slot.

## Abilities

### Make an ability

New Resource > **AbilityData**: `cooldown` and `effects`. Leave `targeting` empty to affect
the user. On the character, add it to **Abilities > Slots** under an action, e.g.
`secondary`. See `abilities/second_wind.tres`.

### Make a spell

Everything else on an AbilityData is optional, and none of it needs code:

| Want | Set |
| --- | --- |
| A mana cost | **Costs**: `mana` and the amount. The character needs a Pool called `mana`. |
| Two charges | **Charges** 2. One comes back every `cooldown` seconds. |
| A wind-up | **Cast Time**. Nothing is spent until it ends. |
| Slowed or rooted while casting | **Status While Casting**: a status with duration 0 |
| Damage interrupts the cast | **Interrupted By Damage** |
| Silence stops it | Add `spells` to **Blocked By**; the Silenced status blocks `spells` |
| A health cost | **Costs**: `health` and the amount. Health is a pool like any other. |
| Only when badly hurt | **Conditions**: a PoolBelowCondition (the pool is `health` by default) |
| Only with someone in range | **Needs Target**, with a Targeting set |
| Something for the caster too | **User Effects**, e.g. the heal half of a life drain |
| Faster cooldowns from gear | A StatModifier on `cooldown_speed`, percent 0.2 |

`abilities/fireball.tres` costs 20 mana, takes half a second to cast and is stopped by a
status that blocks `spells`, such as Silenced.

### Make an ability that throws a projectile

Make a Projectile scene as in "Make a weapon that fires projectiles". Put a
**LaunchProjectileEffect** in the ability's **User Effects** and set its **Projectile** to
that scene. It flies from the user toward where they're aiming. See
`abilities/fireball.tres`.

### Tell the player why an ability failed

```gdscript
func _ready() -> void:
	Abilities.find_on(player).failed.connect(_on_ability_failed)

func _on_ability_failed(_ability: AbilityData, reason: Abilities.Refusal) -> void:
	match reason:
		Abilities.Refusal.COST: show_message("Not enough mana")
		Abilities.Refusal.COOLDOWN: show_message("Not ready yet")
		Abilities.Refusal.BLOCKED: show_message("Can't do that now")
```

`Abilities.can_use(ability)` answers without trying, to grey out a button. The reasons are
the values of `Abilities.Refusal`: `BLOCKED`, `CASTING`, `COOLDOWN`, `COST`, `CONDITION` and
`NO_TARGET`.

### Make an ability that hits everyone nearby

Set the ability's **Targeting** to a new **RadiusTargeting** and choose its radius. With
**Hostile Only** on, it only reaches what the user's Faction fights; for a party heal, turn it
off and **Include User** on. A shockwave is a RadiusTargeting with a DamageEffect and a
KnockbackEffect: see `abilities/shockwave.tres`, which also has two charges.

## Animations

Animations are optional. Timing lives in the Inspector as numbers (**Wind Up**, **Active**,
**Cast Time**), and a game with no animations plays the same as one with them.

### Play an animation when a character attacks, casts or dies

Add an **Animator** to the character and set **Player** to its AnimationPlayer. Then add rows
to **Animations**: an event on the left, picked from the list, and a clip on the right.

| Event | Plays when |
| --- | --- |
| `weapon_started` | A weapon is used, at the click and before any wind-up |
| `weapon_started:sword` | The same, but only for the item whose id is `sword` |
| `weapon_fired` | The shot itself, after the wind-up |
| `weapon_interrupted` | A wind-up is cut short by a stun |
| `ability_cast_started` | A cast begins |
| `ability_used` | An ability goes off |
| `took_damage` | The character is hurt |
| `died` | The character dies |
| `air_mode_entered` | The character leaves the ground |

A row with an id wins over the plain one, and a row whose clip the player doesn't have is
skipped. See the player in `test_level/scenes/player.tscn`.

### Keep a swing animation in step with its hit

Add a marker named `hit` to the clip, at the moment the blade connects or the spell leaves the
hand. The Animator plays the clip faster or slower so the marker lands on the shot: a clip
whose marker is at 0.5 seconds, on a weapon with a Wind Up of 0.25, plays at double speed.
Change the Wind Up and the animation follows. A clip without the marker plays at its own
speed.

### Use an AnimationTree

The Animator drives an AnimationPlayer. With a tree, leave it out and listen to the same
events from the script that drives the tree:

```gdscript
class_name SwingAnimations
extends Node

@export var tree: AnimationTree


func _ready() -> void:
	ComponentManager.of(owner).event(&"weapon_started").connect(_on_weapon_started)


func _on_weapon_started(_ctx: EffectContext) -> void:
	tree.set("parameters/Swing/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
```

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

In a component, ask for the event in `_start()`. The method is called each time it's sent to
this character, until the component stops:

```gdscript
func _start() -> void:
	on(&"took_damage", _on_took_damage)

func _on_took_damage(ctx: EffectContext) -> void:
	print("%s %s damage from %s" % [ctx.amount, ctx.damage_type, ctx.source])
```

Each event is a Godot signal on the character's manager. A script that isn't a component,
such as a HUD, connects to it:
`ComponentManager.of(player).event(&"took_damage").connect(_on_player_hurt)`. An item
component hears its wielder with `on(&"killed", _on_wielder_killed, wielder)`. To hear every
event of a character, for a combat log, connect to the manager's `event_sent`.

| Event | When | Status triggers |
| --- | --- | --- |
| `started` | The character has finished starting | No |
| `dealing_damage`, `taking_damage` | Before a hit lands; change `ctx.add`, `ctx.percent` and `ctx.mul` | Yes |
| `absorbing_damage` | The hit's final number is in `ctx.amount`; a shield lowers it | Yes |
| `dealt_damage`, `took_damage` | After a hit lands; `ctx.amount` is what landed | Yes |
| `giving_healing`, `receiving_healing` | Before healing lands; change it as for damage | Yes |
| `gave_healing`, `received_healing` | After healing lands | Yes |
| `died` | Health reached 0 | When something dealt the killing blow |
| `killed` | This character dealt a killing blow; `ctx.target` died | Yes |
| `revived` | `Health.revive()` brought it back | No |
| `ability_cast_started`, `ability_used`, `ability_interrupted` | An ability; `ctx.origin` is its AbilityData | Yes |
| `inventory_changed` | Something was added to or removed from the Inventory | No |
| `walk_mode_entered`, `air_mode_entered` | Landing, and jumping or walking off a ledge | Yes |
| `<mode>_exited` | A movement mode hands over, e.g. `walk_mode_exited` | Yes |
| `dash_move_started`, `dash_move_finished` | A dash starts and ends; any layered move sends `<move>_started` and `<move>_finished` | Yes |

Send your own with `ComponentManager.notify(node, &"my_event")`, and status triggers react to
it too. To say who caused it, pass a context as well:
`ComponentManager.notify(node, &"my_event", EffectContext.new(who, node))`.

Status triggers react first, then listeners hear the event in the order they connected, so
a listener always sees a hit after every status has changed it.

### Hear events from the whole level

`WorldEvents` hears every character's events in one place, for experience, quest counters, a
kill feed or achievements. Nothing needs adding to the scene:

```gdscript
func _ready() -> void:
	WorldEvents.event(&"died").connect(_on_anything_died)

func _on_anything_died(who: Node, ctx: EffectContext) -> void:
	if who.is_in_group(&"enemy") and ctx and ctx.source == player:
		ComponentManager.of(player).add_base(&"experience", 25)
```

The connection ends by itself when the listening node is freed.

### Add a stat or a damage type

- **A stat:** list it in the ComponentManager's **Stats** (see "Give a character its own stats").
  For a number one of your own components uses, return it from the component's `_stats()`,
  e.g. `{ &"max_stamina": max_stamina }`, and read it with `stat(&"max_stamina")`. Either way,
  statuses change it with a StatModifier of that name.
- **A damage type:** type any name in a DamageEffect's `type`, e.g. `lightning`. Resistance to
  it is the `resist_lightning` stat: add `lightning` to **Health > Resistances**, or give a
  status a StatModifier on `resist_lightning`. Extra damage dealt with it is the
  `bonus_lightning` stat, which needs no setting up.

### Write your own effect, condition or component

The Extending the system page of the documentation has a complete, tested example of each,
also in `starter_pack/scripts/`. In short:

- **Effect:** extend `Effect` and override `_execute(ctx)`. The target may have none of the
  components you need, so check for null. If it has a number, extend `AmountEffect` instead:
  it brings the **Amount** and **Scaling** fields, and `total(ctx)` adds them up.
- **Condition:** extend `SubjectCondition` and override `_test(node) -> bool`. To compare
  both sides, extend `Condition` and override `_passes(ctx)`, as `IsHostileCondition` does.
- **Amount:** extend `Amount` and override `value(ctx) -> float`. It then fits in every
  Scaling list.
- **Component:** extend `Component`. Do your setup in `_start()` (not `_ready()`), list what
  you need in `_requires()`, and numbers statuses may change in `_stats()`. Its
  `_process()` only runs while it's running. Give stat modifiers and statuses with
  `hold_modifier()` and `hold_status()`, which take them back when it stops. See
  `starter_pack/scripts/sprint.gd`.
- **Item component:** extend `ItemComponent`. `wielder`, `item` and `brain` are ready in
  `_start()`. Its `hold_modifier()` and `hold_status()` act on the wielder; anything else it
  changes there must be undone in `_stop()`. See `starter_pack/scripts/scope.gd`.
- **A new way for a weapon to hit** (a cone, a beam, chain lightning): extend
  `WeaponDelivery` and write `_fire()`. The trigger, the **Effects** list and
  `context_for(what_was_hit)` come with it. See `character/items/melee_sweep.gd`.

Name a field `stat`, `pool`, `event`, `tag`, `tags`, `blocks` or `blocked_by`, start the
script with `@tool`, and the Inspector offers the project's names for it, like the built-in
fields. To reach your component from other scripts, `Component.of(node, MyType) as MyType`
works for any type; the built-in ones have a shortcut, such as `Health.find_on(node)`.

A complete effect, which moves mana from the target to whoever caused it:

```gdscript
# With a class_name, it appears in the effect list in the Inspector.
@tool  # So the Inspector lists the project's pools for the field below.
class_name SiphonEffect
extends AmountEffect  # Brings Amount and Scaling: the most taken each time.

## The pool to take from and give to, e.g. &"mana".
@export var pool: StringName = &"mana"


# It works wherever effects do: a weapon's hit, an ability, a status tick.
func _execute(ctx: EffectContext) -> void:
	var theirs := Pool.named(ctx.target, pool)
	if not theirs:  # The target may have no such pool, or be a wall.
		return
	var taken: float = minf(theirs.current, total(ctx))
	theirs.change(-taken)
	var mine := Pool.named(ctx.source, pool)
	if mine:
		mine.change(taken)
```

### Write your own movement mode or move

Both go under the `CharacterMotor`, as children. Pick by asking whether it replaces how the
character moves or adds to it:

- **Movement mode:** replaces it, such as flying, swimming or climbing. Only one mode is in
  charge at a time. Extend `MovementMode`.
- **Layered move:** adds to whatever mode is in charge, for a while, such as a dash, a glide
  or a jump pad. Several can run at once. Extend `LayeredMove`.

The parts to override:

| Override | Mode or move | What it's for |
| --- | --- | --- |
| `_physics_update(delta)` | Both | Set `body.velocity`. Runs every physics frame while it's in charge or active. Never call `move_and_slide()`: the motor does, once everything has run. |
| `_can_enter() -> bool` | Mode | Return true to take over from the mode in charge, e.g. once in water. The other modes don't need to know about yours. |
| `_get_next_mode() -> MovementMode` | Mode | Return the mode to hand over to, or null to stay. |
| `_can_start() -> bool` | Move | Return true to start, e.g. `return motor.consume_action(&"dash")`. |
| `_enter()`, `_exit()` | Both | Setup and cleanup when it takes over or starts, and when it hands over or ends. Use these, not `_ready()`. |
| `_stats()` | Both | Numbers statuses may change, as in a component. Read them with `stat()`. |
| `cooldown` (Inspector) | Move | Time from one start to the next. While it counts down, `_can_start()` isn't asked, so the press is left for something else. |
| `blocked_by` (Inspector) | Both | Names of its own that a status can block. See "Stop movement with a status". |

Inside, `body` is the character, `motor.brain` gives `move_dir` and held buttons, and
`motor.consume_action(&"jump")` uses up a press so nothing else acts on it. A move sets
`active = false` to end itself. The motor sends events for yours too, named after the class,
e.g. `fly_mode_entered`, so status triggers can react to it.

A complete mode, to fly while a button toggles it:

```gdscript
# With a class_name, it appears in the Add Child Node dialog.
class_name FlyMode
extends MovementMode

## Flying speed, in metres per second.
@export var fly_speed: float = 8.0


# Asked while another mode is in charge: pressing fly takes over.
func _can_enter() -> bool:
	return motor.consume_action(&"fly")


# Move where the brain points, and rise while jump is held. No gravity.
func _physics_update(_delta: float) -> void:
	body.velocity = motor.brain.move_dir * fly_speed
	if motor.brain.is_action_pressed(&"jump"):
		body.velocity.y = fly_speed


# Pressing fly again lands: hand back to walking, or to falling if in the air.
func _get_next_mode() -> MovementMode:
	if not motor.consume_action(&"fly"):
		return null
	return motor.get_mode(WalkMode) if body.is_on_floor() else motor.get_mode(AirMode)
```

Add it as a child of the `CharacterMotor`, beside the WalkMode and AirMode, and add a `fly`
action to the Input Map and to **PlayerBrain > Extra Actions**. Nothing else changes: the
walk and air modes keep working, and the motor hands over to `FlyMode` when it asks. For a
layered move, see `starter_pack/scripts/glide_move.gd`.

## Show it on screen

### Show health, statuses, ammo and cooldowns

For a label above a character's head with its name, health and statuses, add a **Nameplate**
as its child (`starter_pack/scripts/nameplate.gd`). The rest of this recipe is about the
player's own HUD.

`starter_pack/scripts/character_hud.gd` (**CharacterHud**) does all four, and fills a
ProgressBar named ChargeBar while a weapon charges, if you add one. Attach it to a Control,
add a ProgressBar named HealthBar and Labels named Statuses, Ammo and Cooldown under it, and set
**Character** to the player and **Ability** to one of its abilities. To build your own, read
these:

| Show | Read |
| --- | --- |
| Health bar | `Health.changed(current, maximum)`; `current` and `maximum()` for the first draw |
| Status bar | `Statuses.changed`, then `Statuses.active`: each StatusData's `display_name` and `icon`, and its `stacks` and `time_left` |
| Ammo | `Component.of(gear.node_in(&"weapon"), Magazine)`, then its `rounds` and `capacity` |
| Cooldown | `Abilities.cooldown_left(ability)`, and `charges_left(ability)` for one with charges |
| Cast bar | `Abilities.cast_started` and `used`, then `cast_progress()` every frame |
| Charge bar | `Trigger.find_on(gear.node_in(&"weapon"))`, then `is_charging()` and `charge`, from 0 to 1 |
| Health, mana, stamina, shield | `Pool.named(player, &"mana")`, then its `changed(current, maximum)`. Health is the pool named `health`. |
| Damage numbers | Subscribe to `took_damage` (see "React to an event"): `ctx.amount`, `ctx.hit_position()`, and `ctx.has_tag(&"crit")` to colour it |
| Why a stat has its value | `manager.base_of(&"move_speed")` and `manager.modifiers_of(&"move_speed")`: each modifier and the status or item behind it |
| Dash cooldown | `cooldown_left()` on the DashMove, or any layered move |
| Air jumps left | `jumps_left` on the AirMode |

## Find out what's going on

- **Run the game and open the Remote tab** in the Scene dock. Click a character's
  **Statuses** to see `active`: each status it has, with its stacks and time left.
- **A status didn't land?** Connect to `Statuses.refused`. It fires with the status that
  was turned away, by an immunity or a failed `apply_conditions`.
- **An ability won't fire?** Connect to `Abilities.failed`, or print
  `abilities.why_not(ability)`. See "Tell the player why an ability failed".
- **A hit does the wrong damage?** Connect to the `took_damage` event and print the context:
  `ctx.amount` is what landed, and `ctx.damage_type` and `ctx.tags` say what kind of hit it
  was.
- **A component does nothing?** Check the Output panel for "can't start: it needs …".
- `ComponentManager.stat_of(node, &"move_speed")` prints any stat's current value.
- **Which way is it moving?** In the Remote tab, click the **CharacterMotor**: its `mode` is
  the mode in charge. To log every handover, connect to `CharacterMotor.mode_changed`, which
  gives the old and new mode.
- **A mode or move does nothing?** It must be a child of the CharacterMotor; anywhere else it
  shows a warning triangle. A move that never starts usually has an action the brain never
  presses: the action must be in the Input Map *and* in **PlayerBrain > Extra Actions**.
  PlayerBrain warns in the Output panel when an Extra Action is missing from the Input Map,
  but not the other way round.
