.. _doc_equipment_system:

Equipment system
================

An equippable item is a scene whose root is the model and whose children are its own :ref:`ComponentManager<class_ComponentManager>` and item components; the item does whatever its components do. Item components use the same :ref:`Component<class_Component>` base as characters, plus references to who holds the item and which copy it is.

.. source-file:: ../../character_system/character/items/item_component.gd

.. _doc_equipping:

Equipping
---------

.. source-file:: ../../character_system/character/items/equipment.gd

Equip is "instantiate and attach": the item's components start once the scene is in the tree, with ``wielder`` and ``item`` already set. Unequip is "free": they stop, and connections made with ``listen()`` are undone. The scene is thrown away, but the :ref:`ItemInstance<class_ItemInstance>` and its state survive, so a rifle remembers its rounds when equipped again.

With an :ref:`Inventory<class_Inventory>` beside it, everything equipped is also carried. ``equip()`` adds the item to the Inventory if it isn't there, and ``unequip()`` leaves it there. An equipped item that leaves the Inventory (dropped, sold, used up) is unequipped when Equipment hears ``inventory_changed``. Equipping the item that's already in its slot does nothing.

.. _doc_switching_weapons:

Switching weapons
-----------------

:ref:`WeaponSwitch<class_WeaponSwitch>` lets a character carry several weapons and hold one at a time. Its weapons are the Inventory items whose slot is its ``slot`` (``weapon`` by default), in the order they were picked up. The one held is whatever is in that Equipment slot.

.. source-file:: ../../character_system/character/items/weapon_switch.gd

Players switch with the ``next_weapon`` and ``previous_weapon`` actions, which wrap around. Code, AI and UI call ``cycle()``, ``select()`` or ``holster()``. With ``auto_draw`` on, the hands are never left empty by accident: the first weapon picked up is drawn, and when the held weapon is dropped the first one still carried is drawn. After ``holster()`` the hands stay empty until a switch. Nothing is copied when switching: the same :ref:`ItemInstance<class_ItemInstance>` moves between the bag and the hand, so each weapon keeps its own rounds.

.. _doc_item_components:

Item components
---------------

.. list-table::
   :header-rows: 1

   * - Component
     - Decides
     - Key properties
   * - :ref:`Trigger<class_Trigger>`
     - When the item activates
     - ``action``, ``fire_rate``, ``automatic``, ``buffer_time``, ``blocked_by``,
       ``user_effects``
   * - :ref:`Magazine<class_Magazine>`
     - Whether it may activate, and what it consumes
     - ``ammo``, ``capacity``, ``reload_time``, ``auto_reload``
   * - :ref:`Hitscan<class_Hitscan>`
     - What an instant shot hits and what happens to it
     - ``max_distance``, ``pellets``, ``spread``, ``effects``
   * - :ref:`MeleeSweep<class_MeleeSweep>`
     - What a swing hits: everything inside a shape in front of the item
     - ``shape``, ``offset``, ``effects``
   * - :ref:`Grants<class_Grants>`
     - What the wielder has while the item is equipped: passives, stat changes and abilities
     - ``statuses``, ``modifiers``, ``abilities``

The flow inside an item is a short signal chain: :ref:`Trigger<class_Trigger>` asks :ref:`Magazine<class_Magazine>` (if present) for a round, then emits ``fired``; every :ref:`WeaponDelivery<class_WeaponDelivery>` (:ref:`Hitscan<class_Hitscan>`, :ref:`MeleeSweep<class_MeleeSweep>`, or one of your own) listens for ``fired`` and applies its ``effects`` to what it hits. Each hit's context records the item's :ref:`ItemData<class_ItemData>` as ``origin``, so a kill feed can say "killed by Rifle".

.. source-file:: ../../character_system/character/items/trigger.gd

.. source-file:: ../../character_system/character/items/magazine.gd

``rounds`` is a property with a getter and setter: reading it reads ``item.state``, and assigning it writes ``item.state`` and emits ``changed``. The rest of the code treats it like a normal variable.

-  **A stunned or dead wielder can't fire**, because its :ref:`Brain<class_Brain>` reports no presses. A status that blocks ``weapons``, such as a Disarmed one, stops every Trigger and nothing else; a Trigger's ``blocked_by`` can add names of its own.
-  **The fire rate holds at any frame rate.** After each shot the Trigger keeps what the frame overshot the cooldown by, so 10 shots a second is 10 a second at 30 frames a second and at 144.
-  **Reloading can take time.** With a ``reload_time``, ``reload()`` starts the reload and the rounds arrive when it's done; until then ``take()`` refuses, so the weapon can't fire. ``reload_started`` and ``reload_finished`` are for the animation. Putting the weapon away mid-reload loses it. With ``auto_reload``, pulling the trigger on an empty magazine reloads.
-  **Ammo is optional.** A Magazine with no ``ammo`` item reloads for free, as it does for a wielder without an :ref:`Inventory<class_Inventory>`.

.. _doc_hit_detection_and_hurtboxes:

Hit detection and hurtboxes
---------------------------

A :ref:`Hurtbox<class_Hurtbox>` is an optional ``Area3D`` on a character, such as a head. Hits on it count as hits on its character, scaled by its ``multiplier`` and labelled with its ``tags``. Characters without hurtboxes are hit through their own body collider, so nothing breaks if you skip them.

The tags end up on the hit, where a :ref:`HitCondition<class_HitCondition>` tests them: a head hurtbox tagged ``head`` lets a status give a bonus for headshots, set them alight or count them, with no code. The hit also records where it landed in ``position`` and ``normal``, so a :ref:`SpawnSceneEffect<class_SpawnSceneEffect>` with ``at`` set to ``HIT_POINT`` puts sparks or a decal there.

Shots are physics rays, so collision layers decide what they can hit. ``Hitscan.collision_mask`` lists the layers a weapon hits, every layer by default; untick layers in the inspector to make, for example, a rifle that ignores a turrets layer.

Within those layers, a shot stops at the first body or :ref:`Hurtbox<class_Hurtbox>` in its way, and passes through two things that would otherwise soak it up:

-  **Areas that aren't hurtboxes.** Trigger volumes, door sensors, an enemy's detection range and :ref:`EffectZone<class_EffectZone>`\ s never stop a shot, whatever layer they are on.
-  **Characters that can't be targeted.** A body or hurtbox is passed through while a status on its character blocks ``targeting``. The Dead status does, so a corpse is not cover until it is revived, and a stealth or phased status of your own can too.

Projectiles in flight and the player's crosshair follow the same two rules, because all three use one ray, ``Hurtbox.raycast()``. To make corpses block shots, give the character a death status without ``targeting`` in its Blocks; to let shots through something else, ``stops_shots()`` is the one place to change. Melee swings and blasts take everything inside a shape, so nothing blocks them; a :ref:`DamageEffect<class_DamageEffect>` leaves the dead alone either way.

A weapon's own wielder is never hit: every :ref:`WeaponDelivery<class_WeaponDelivery>` collects the wielder's body and hurtboxes once, when the weapon is equipped, and every shot passes through them.

.. source-file:: ../../character_system/character/combat/hurtbox.gd

.. source-file:: ../../character_system/character/items/weapon_delivery.gd

.. source-file:: ../../character_system/character/items/hitscan.gd

``pellets`` and ``spread`` make a shotgun: each pellet is its own ray, strays up to ``spread`` degrees from the aim, and applies the effects by itself, so a close target takes most of them and a far one a few.

.. source-file:: ../../character_system/character/items/melee_sweep.gd

:ref:`MeleeSweep<class_MeleeSweep>` and :ref:`Hitscan<class_Hitscan>` share a base class, :ref:`WeaponDelivery<class_WeaponDelivery>`, which holds the effects and the collision mask, waits for the :ref:`Trigger<class_Trigger>` and builds each hit's context with ``context_for()``. Each of them only writes ``_fire()``: what one shot reaches. MeleeSweep hits each character once per swing, through its most vulnerable part inside the shape. :ref:`doc_extending_item_component` covers writing your own.

.. _doc_projectiles:

Projectiles
-----------

A :ref:`Projectile<class_Projectile>` is a shot that takes time to arrive: a rocket, a fireball, an arrow, a thrown grenade. It is a scene with the Projectile script on its root and a mesh or particles under it, and it needs no collision shape.

.. source-file:: ../../character_system/character/world/projectile.gd

.. source-file:: ../../character_system/character/effects/launch_projectile_effect.gd

-  **One effect launches it.** A :ref:`LaunchProjectileEffect<class_LaunchProjectileEffect>` launches toward the aim of whoever caused the effect. In a :ref:`Trigger<class_Trigger>`'s ``user_effects``, which run on the wielder at each shot, it makes a rocket launcher or a bow, and the projectile leaves from the weapon: the Trigger passes the item's position on in the context. In an ability's effects it throws a fireball, and in an item's ``use_effects`` a grenade; those leave from the character, a little in front of the chest. Code calls ``Projectile.launch()``.
-  **It moves with a ray.** Each physics frame it casts a ray from where it is to where it will be, so a fast projectile can't pass through a thin wall, and it hits and passes through the same things a :ref:`Hitscan<class_Hitscan>` shot does. It never hits whoever launched it directly.
-  **The launcher hands over effects.** The effect's ``effects`` run on what the projectile hits, before the projectile scene's own, so one rocket scene can serve several weapons with different damage.
-  **A blast is a second list.** With a ``blast_radius``, ``blast_effects`` run on everything in range of the impact, once per character, including what was hit and, unless a condition says otherwise, the shooter. ``blast_edge_strength`` fades it toward the edge through ``magnitude``. Put an :ref:`IsHostileCondition<class_IsHostileCondition>` on a blast effect to spare allies.
-  **It outlives its launcher.** The projectile is added to the level, and its hits credit the launcher as ``source`` and the weapon or ability as ``origin``, so kills are attributed even if the weapon was put away meanwhile.
-  **Time runs out.** After ``lifetime`` seconds a projectile with a blast goes off where it is, and one without disappears.

``starter_pack/projectiles/fireball.tscn`` is a projectile with a direct hit that grows with ``spell_power``, a burn and a blast. ``rocket.tscn`` has a blast with knockback, and ``grenade.tscn`` arcs and goes off after two seconds; ``starter_pack/items/rocket_launcher.tres`` and ``grenade.tres`` launch them.

.. _doc_passives_from_equipment:
.. _doc_stats_and_abilities_from_equipment:

Passives, stats and abilities from equipment
--------------------------------------------

.. source-file:: ../../character_system/character/items/grants.gd

One :ref:`Grants<class_Grants>` component gives the wielder everything an item gives while it is equipped, and takes it all back on unequip. Fill in whichever of its three lists the item needs.

**Statuses.** ``drop_hold()`` drops one hold instead of removing the status outright. Two rings that grant Haste keep it until both are taken off. ``_granted`` remembers which passives were accepted, so an item whose passive was refused by an apply condition doesn't drop a hold that belongs to another item.

**Modifiers** are the shortest way to put numbers on gear: they go straight onto the wielder's manager, with the item as their source. No status file is needed. Use a status instead when the bonus should appear on a status bar, grant an immunity or react to events.

Modifiers in the copy's ``state`` under ``modifiers`` are applied as well, which is how loot with random numbers works: the item scene is the same for every copy, and each :ref:`ItemInstance<class_ItemInstance>` carries its own rolls.

**Abilities** go in the wielder's :ref:`Abilities<class_Abilities>` slots while the item is equipped, and what was there before is restored afterwards. Cooldowns belong to the wielder, so swapping the item out and back in doesn't reset them.

.. _doc_example_items:

Example items
-------------

These ship in ``character_system/starter_pack/items/``, each an :ref:`ItemData<class_ItemData>` ``.tres`` with its scene in ``scenes/``.

.. list-table::
   :header-rows: 1

   * - Item
     - Slot
     - Components
   * - Rifle (``rifle.tres``)
     - ``weapon``
     - :ref:`Trigger<class_Trigger>` (5 per second), :ref:`Magazine<class_Magazine>` (12 rounds,
       rifle ammo), :ref:`Hitscan<class_Hitscan>` [10 physical damage; 5 more if the target is
       wet]
   * - Flare gun (``flare_gun.tres``)
     - ``weapon``
     - :ref:`Trigger<class_Trigger>` (2 per second), :ref:`Magazine<class_Magazine>` (2 rounds),
       :ref:`Hitscan<class_Hitscan>` [2 fire damage, apply Burning]
   * - Fireproof cloak (``fireproof_cloak.tres``)
     - ``cloak``
     - :ref:`Grants<class_Grants>` [Fireproof]
   * - Ward amulet (``ward_amulet.tres``)
     - ``neck``
     - :ref:`Grants<class_Grants>` [Warded]
   * - Rifle ammo (``rifle_ammo.tres``)
     - none
     - None: it's only carried, up to 60 per stack, and the rifle's Magazine reloads from it.
   * - Shotgun (``shotgun.tres``)
     - ``weapon``
     - :ref:`Trigger<class_Trigger>` (1.5 per second), :ref:`Magazine<class_Magazine>` (6
       shells, no ammo item, 1.2 second reload, auto reload), :ref:`Hitscan<class_Hitscan>` [8
       pellets in a 4 degree cone, 3 physical damage each]
   * - Fire staff (``fire_staff.tres``)
     - ``weapon``
     - :ref:`Grants<class_Grants>` [Fireball on ``secondary``, ``bonus_fire`` +0.2]
   * - Ring of vigor (``ring_of_vigor.tres``)
     - ``ring``
     - :ref:`Grants<class_Grants>` [``max_health`` +25]
   * - Health potion (``health_potion.tres``)
     - none
     - None: it has ``use_effects`` [heal 40], and ``Inventory.use()`` takes one from the
       stack of up to 5.
   * - Mana potion (``mana_potion.tres``)
     - none
     - None: ``use_effects`` [a :ref:`ChangePoolEffect<class_ChangePoolEffect>` of 50 mana].
   * - Grenade (``grenade.tres``)
     - none
     - None: ``use_effects`` [a :ref:`LaunchProjectileEffect<class_LaunchProjectileEffect>`
       with ``projectiles/grenade.tscn``, which arcs and has a blast], so using one throws it.
   * - Sword (``sword.tres``)
     - ``weapon``
     - :ref:`Trigger<class_Trigger>` (2 per second), :ref:`MeleeSweep<class_MeleeSweep>` [8
       damage + 0 to 4 at random + 1 per point of ``strength``, tagged ``melee``; knockback;
       apply Bleeding]
   * - Rocket launcher (``rocket_launcher.tres``)
     - ``weapon``
     - :ref:`Trigger<class_Trigger>` [``user_effects`` = a
       :ref:`LaunchProjectileEffect<class_LaunchProjectileEffect>` with
       ``projectiles/rocket.tscn``; 40 damage on a direct hit],
       :ref:`Magazine<class_Magazine>` (1 rocket, 1.5 second reload, auto reload)
   * - Rockets (``rockets.tres``)
     - none
     - None: ammo for the rocket launcher, up to 20 per stack.
   * - Marksman rifle (``marksman_rifle.tres``)
     - ``weapon``
     - :ref:`Trigger<class_Trigger>` (1.5 per second), :ref:`Magazine<class_Magazine>` (5
       rounds of rifle ammo, 1.5 second reload), :ref:`Hitscan<class_Hitscan>` [35 damage; a
       :ref:`SpawnSceneEffect<class_SpawnSceneEffect>` of sparks at the hit point], and the
       example :ref:`Scope<class_Scope>`
   * - Soldier rifle (``soldier_rifle.tres``)
     - ``weapon``
     - For AI. :ref:`Trigger<class_Trigger>` (2 per second), :ref:`Magazine<class_Magazine>`
       (8 rounds, no ammo item, auto reload), :ref:`Hitscan<class_Hitscan>` [8 damage with an
       :ref:`IsHostileCondition<class_IsHostileCondition>`, so no friendly fire]

More ideas, built from the same parts:

.. list-table::
   :header-rows: 1

   * - Item
     - Components
     - Result
   * - Assault rifle
     - :ref:`Trigger<class_Trigger>` (automatic, 10 per second), :ref:`Magazine<class_Magazine>` (30, rifle ammo), :ref:`Hitscan<class_Hitscan>` [damage]
     - Full-auto, ammo-limited hitscan weapon
   * - Flaming sword
     - :ref:`Trigger<class_Trigger>` (1.5 per second), :ref:`MeleeSweep<class_MeleeSweep>` [damage, apply Burning]
     - Melee weapon that sets targets on fire
   * - Storm rod
     - :ref:`Trigger<class_Trigger>`, :ref:`Hitscan<class_Hitscan>` [lightning damage, extra lightning damage if target has tag ``wet``]
     - Rewards combining with water, using a condition
   * - Healing staff
     - :ref:`Trigger<class_Trigger>`, :ref:`Hitscan<class_Hitscan>` [heal]
     - Same delivery, friendly effect
   * - Ring of haste
     - :ref:`Grants<class_Grants>` [a Haste passive with duration 0]
     - No trigger at all, only a passive
   * - Bow
     - :ref:`Trigger<class_Trigger>` [``user_effects`` = a
       :ref:`LaunchProjectileEffect<class_LaunchProjectileEffect>` with a Projectile with
       ``gravity_scale`` 1; damage with a :ref:`StatAmount<class_StatAmount>` of ``dexterity``]
     - Arrows that arc, and hit harder as the archer levels
   * - Looted ring with random numbers
     - :ref:`Grants<class_Grants>` with nothing listed; the rolls are in each
       copy's ``state``
     - One scene, a different ring every drop
   * - Vampiric blade
     - A sword + :ref:`Grants<class_Grants>` [the example Vampiric passive]
     - Heals its wielder for a share of every hit
   * - Cursed rifle
     - The rifle + :ref:`Grants<class_Grants>` [a Fragile passive]
     - A weapon and a passive drawback in one item
