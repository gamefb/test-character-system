.. _doc_example_items:

Items
=====

What a character can pick up, wear, fire and drink. An item is an :ref:`ItemData<class_ItemData>` file, and one that is worn or held has a scene of item components beside it; :ref:`doc_equipment_system` covers how those work.

.. _doc_example_item_list:

The items
---------

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

.. _doc_example_projectiles:

Projectiles
-----------

These ship in ``character_system/starter_pack/projectiles/`` as scenes with a :ref:`Projectile<class_Projectile>` at the root; :ref:`doc_projectiles` covers how they fly and what they hit.

.. list-table::
   :header-rows: 1

   * - Projectile
     - What it does
     - Used by
   * - Fireball (``fireball.tscn``)
     - Flies straight and bursts over 3 metres, setting alight what it catches.
     - The Fireball ability and the fire staff that grants it
   * - Rocket (``rocket.tscn``)
     - Flies straight and bursts over 4 metres.
     - The rocket launcher
   * - Grenade (``grenade.tscn``)
     - Thrown in an arc, and bursts over 4 metres after 2 seconds.
     - The grenade, a consumable
   * - Spark (``spark.tscn``)
     - A scene with nothing but a short-lived light, spawned where something goes off.
     - The rocket, the grenade and the marksman rifle
