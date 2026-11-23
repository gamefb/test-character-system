.. _doc_equipment_system:

Equipment system
================

An equippable item is a scene whose root is the model and whose children are its own :ref:`ComponentManager<class_ComponentManager>` and item components; the item does whatever its components do. Item components use the same :ref:`Component<class_Component>` base as characters, plus references to who holds the item and which copy it is.

.. source-file:: ../../character_system/items/components/_base/item_component.gd

.. _doc_equipping:

Equipping
---------

.. source-file:: ../../character_system/characters/components/equipment.gd

Equip is "instantiate and attach": the item's components start once the scene is in the tree, with ``wielder`` and ``item`` already set. Unequip is "free": they stop, and connections made with ``listen()`` are undone. The scene is thrown away, but the :ref:`ItemInstance<class_ItemInstance>` and its state survive, so a rifle remembers its rounds when equipped again.

With an :ref:`Inventory<class_Inventory>` beside it, everything equipped is also carried. ``equip()`` adds the item to the Inventory if it isn't there, and ``unequip()`` leaves it there. An equipped item that leaves the Inventory (dropped, sold, used up) is unequipped when Equipment hears ``inventory_changed``. Equipping the item that's already in its slot does nothing.

.. _doc_switching_weapons:

Switching weapons
-----------------

:ref:`WeaponSwitch<class_WeaponSwitch>` lets a character carry several weapons and hold one at a time. Its weapons are the Inventory items whose slot is its ``slot`` (``weapon`` by default), in the order they were picked up. The one held is whatever is in that Equipment slot.

.. source-file:: ../../character_system/characters/components/weapon_switch.gd

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
     - ``action``, ``fire_rate``, ``automatic``, ``buffer_time``, ``blocked_by_tags``
   * - :ref:`Magazine<class_Magazine>`
     - Whether it may activate, and what it consumes
     - ``ammo``, ``capacity``, ``reload_time``, ``auto_reload``
   * - :ref:`Hitscan<class_Hitscan>`
     - What an instant shot hits and what happens to it
     - ``max_distance``, ``pellets``, ``spread``, ``effects``
   * - :ref:`MeleeSweep<class_MeleeSweep>`
     - What a swing hits: everything inside a shape in front of the item
     - ``shape``, ``offset``, ``effects``
   * - :ref:`Launcher<class_Launcher>`
     - Which :ref:`Projectile<class_Projectile>` a shot sends out
     - ``projectile``, ``effects``, ``count``, ``spread``
   * - :ref:`GrantStatuses<class_GrantStatuses>`
     - Passives the wielder has while the item is equipped
     - ``statuses``
   * - :ref:`GrantModifiers<class_GrantModifiers>`
     - Stat changes the wielder has while the item is equipped
     - ``modifiers``
   * - :ref:`GrantAbilities<class_GrantAbilities>`
     - Abilities the wielder has while the item is equipped
     - ``abilities``

The flow inside an item is a short signal chain: :ref:`Trigger<class_Trigger>` asks :ref:`Magazine<class_Magazine>` (if present) for a round, then emits ``fired``; every delivery component (:ref:`Hitscan<class_Hitscan>`, :ref:`MeleeSweep<class_MeleeSweep>`, :ref:`Launcher<class_Launcher>`) listens for ``fired`` and applies its ``effects`` to what it hits. Each hit's context records the item's :ref:`ItemData<class_ItemData>` as ``origin``, so a kill feed can say "killed by Rifle".

.. source-file:: ../../character_system/items/components/trigger.gd

.. source-file:: ../../character_system/items/components/magazine.gd

``rounds`` is a property with a getter and setter: reading it reads ``item.state``, and assigning it writes ``item.state`` and emits ``changed``. The rest of the code treats it like a normal variable.

-  **A stunned or dead wielder can't fire**, because its :ref:`Brain<class_Brain>` reports no presses. ``blocked_by_tags`` on the Trigger is for statuses that stop weapons only, such as Disarmed.
-  **The fire rate holds at any frame rate.** After each shot the Trigger keeps what the frame overshot the cooldown by, so 10 shots a second is 10 a second at 30 frames a second and at 144.
-  **Reloading can take time.** With a ``reload_time``, ``reload()`` starts the reload and the rounds arrive when it's done; until then ``take()`` refuses, so the weapon can't fire. ``reload_started`` and ``reload_finished`` are for the animation. Putting the weapon away mid-reload loses it. With ``auto_reload``, pulling the trigger on an empty magazine reloads.
-  **Ammo is optional.** A Magazine with no ``ammo`` item reloads for free, as it does for a wielder without an :ref:`Inventory<class_Inventory>`.

.. _doc_hit_detection_and_hurtboxes:

Hit detection and hurtboxes
---------------------------

A :ref:`Hurtbox<class_Hurtbox>` is an optional ``Area3D`` on a character, such as a head. Hits on it count as hits on its character, scaled by its ``multiplier`` and labelled with its ``tags``. Characters without hurtboxes are hit through their own body collider, so nothing breaks if you skip them.

The tags end up on the hit, where a :ref:`HitTagCondition<class_HitTagCondition>` tests them: a head hurtbox tagged ``head`` lets a status give a bonus for headshots, set them alight or count them, with no code. The hit also records where it landed in ``position`` and ``normal``, so a :ref:`SpawnSceneEffect<class_SpawnSceneEffect>` with ``at`` set to ``HIT_POINT`` puts sparks or a decal there.

Shots are physics rays, so collision layers decide what they can hit. ``Hitscan.collision_mask`` lists the layers a weapon hits, every layer by default; untick layers in the inspector to make, for example, a rifle that ignores a turrets layer. The ray also hits areas, which is how hurtboxes get hit. :ref:`EffectZone<class_EffectZone>` therefore sets its own layer to 0, so shots and AI sight lines pass through fire patches and pools. A zone still detects bodies, because detection uses its mask, not its layer.

A weapon's own wielder is never hit: :ref:`Hitscan<class_Hitscan>` collects the wielder's body and hurtboxes once, when the weapon is equipped, and every shot passes through them.

.. source-file:: ../../character_system/characters/hurtbox.gd

.. source-file:: ../../character_system/items/components/hitscan.gd

``pellets`` and ``spread`` make a shotgun: each pellet is its own ray, strays up to ``spread`` degrees from the aim, and applies the effects by itself, so a close target takes most of them and a far one a few.

.. source-file:: ../../character_system/items/components/melee_sweep.gd

:ref:`MeleeSweep<class_MeleeSweep>` follows the :ref:`Hitscan<class_Hitscan>` pattern: require :ref:`Trigger<class_Trigger>`, listen to ``fired`` in ``_start()``, find targets, and build each context with ``Hurtbox.hit()``. It hits each character once per swing, through its most vulnerable part inside the shape. :ref:`doc_extending_item_component` covers writing your own.

.. _doc_projectiles:

Projectiles
-----------

A :ref:`Projectile<class_Projectile>` is a shot that takes time to arrive: a rocket, a fireball, an arrow, a thrown grenade. It is a scene with the Projectile script on its root and a mesh or particles under it, and it needs no collision shape.

.. source-file:: ../../character_system/world/projectile.gd

.. source-file:: ../../character_system/items/components/launcher.gd

-  **Two ways to launch one.** A :ref:`Launcher<class_Launcher>` on a weapon launches on each :ref:`Trigger<class_Trigger>` shot, from the item toward the wielder's aim. A :ref:`LaunchProjectileEffect<class_LaunchProjectileEffect>` launches from whoever caused the effect, so an ability throws a fireball. Code calls ``Projectile.launch()``.
-  **It moves with a ray.** Each physics frame it casts a ray from where it is to where it will be, so a fast projectile can't pass through a thin wall, and it hits hurtboxes as :ref:`Hitscan<class_Hitscan>` does. It never hits whoever launched it directly.
-  **The launcher hands over effects.** The Launcher's ``effects`` run on what the projectile hits, before the projectile scene's own, so one rocket scene can serve several weapons with different damage.
-  **A blast is a second list.** With a ``blast_radius``, ``blast_effects`` run on everything in range of the impact, once per character, including what was hit and, unless a condition says otherwise, the shooter. ``blast_edge_strength`` fades it toward the edge through ``magnitude``. Put an :ref:`IsHostileCondition<class_IsHostileCondition>` on a blast effect to spare allies.
-  **It outlives its launcher.** The projectile is added to the level, and its hits credit the launcher as ``source`` and the weapon or ability as ``origin``, so kills are attributed even if the weapon was put away meanwhile.
-  **Time runs out.** After ``lifetime`` seconds a projectile with a blast goes off where it is, and one without disappears.

``examples/projectiles/fireball.tscn`` is a projectile with a direct hit that grows with ``spell_power``, a burn and a blast.

.. _doc_passives_from_equipment:

Passives from equipment
-----------------------

.. source-file:: ../../character_system/items/components/grant_statuses.gd

``drop_hold()`` drops one hold instead of removing the status outright. Two rings that grant Haste keep it until both are taken off. ``_granted`` remembers which passives were accepted, so an item whose passive was refused by an apply condition doesn't drop a hold that belongs to another item.

.. _doc_stats_and_abilities_from_equipment:

Stats and abilities from equipment
----------------------------------

.. source-file:: ../../character_system/items/components/grant_modifiers.gd

:ref:`GrantModifiers<class_GrantModifiers>` is the shortest way to put numbers on gear: the modifiers go straight onto the wielder's manager, with the item as their source, and come off on unequip. No status file is needed. Use :ref:`GrantStatuses<class_GrantStatuses>` when the bonus should appear on a status bar, grant an immunity or react to events.

Modifiers in the copy's ``state`` under ``modifiers`` are applied as well, which is how loot with random numbers works: the item scene is the same for every copy, and each :ref:`ItemInstance<class_ItemInstance>` carries its own rolls.

.. source-file:: ../../character_system/items/components/grant_abilities.gd

:ref:`GrantAbilities<class_GrantAbilities>` puts abilities in the wielder's :ref:`Abilities<class_Abilities>` slots while the item is equipped and restores what was there before. Cooldowns belong to the wielder, so swapping the item out and back in doesn't reset them.

.. _doc_example_items:

Example items
-------------

These ship in ``character_system/examples/items/``, each an :ref:`ItemData<class_ItemData>` ``.tres`` with its scene in ``scenes/``.

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
     - :ref:`GrantStatuses<class_GrantStatuses>` [Fireproof]
   * - Ward amulet (``ward_amulet.tres``)
     - ``neck``
     - :ref:`GrantStatuses<class_GrantStatuses>` [Warded]
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
     - :ref:`GrantAbilities<class_GrantAbilities>` [Fireball on ``secondary``],
       :ref:`GrantModifiers<class_GrantModifiers>` [``bonus_fire`` +0.2]
   * - Ring of vigor (``ring_of_vigor.tres``)
     - ``ring``
     - :ref:`GrantModifiers<class_GrantModifiers>` [``max_health`` +25]
   * - Health potion (``health_potion.tres``)
     - none
     - None: it has ``use_effects`` [heal 40], and ``Inventory.use()`` takes one from the
       stack of up to 5.

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
     - :ref:`GrantStatuses<class_GrantStatuses>` [a Haste passive with duration 0]
     - No trigger at all, only a passive
   * - Rocket launcher
     - :ref:`Trigger<class_Trigger>`, :ref:`Magazine<class_Magazine>` (1 rocket, 2 second
       reload), :ref:`Launcher<class_Launcher>` [a Projectile with a blast]
     - Slow, heavy, and dangerous up close
   * - Bow
     - :ref:`Trigger<class_Trigger>`, :ref:`Launcher<class_Launcher>` [a Projectile with
       ``gravity_scale`` 1; damage with a :ref:`StatAmount<class_StatAmount>` of ``dexterity``]
     - Arrows that arc, and hit harder as the archer levels
   * - Looted ring with random numbers
     - :ref:`GrantModifiers<class_GrantModifiers>` with nothing listed; the rolls are in each
       copy's ``state``
     - One scene, a different ring every drop
   * - Vampiric blade
     - A sword + :ref:`GrantStatuses<class_GrantStatuses>` [the example Vampiric passive]
     - Heals its wielder for a share of every hit
   * - Cursed rifle
     - The rifle + :ref:`GrantStatuses<class_GrantStatuses>` [a Fragile passive]
     - A weapon and a passive drawback in one item
