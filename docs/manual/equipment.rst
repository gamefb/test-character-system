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
     - ``action``, ``fire_rate``, ``automatic``, ``buffer_time``
   * - :ref:`Magazine<class_Magazine>`
     - Whether it may activate, and what it consumes
     - ``ammo``, ``capacity``
   * - :ref:`Hitscan<class_Hitscan>`
     - What an instant shot hits and what happens to it
     - ``max_distance``, ``effects``
   * - ``ProjectileLauncher``
     - Spawns a projectile scene that carries the effects
     - ``projectile``, ``speed``, ``effects``
   * - ``MeleeSweep``
     - What a swing hits, using a shape cast
     - ``shape``, ``effects``
   * - :ref:`GrantStatuses<class_GrantStatuses>`
     - Passives the wielder has while the item is equipped
     - ``statuses``

The flow inside an item is a short signal chain: :ref:`Trigger<class_Trigger>` asks :ref:`Magazine<class_Magazine>` (if present) for a round, then emits ``fired``; every delivery component (:ref:`Hitscan<class_Hitscan>`, ``ProjectileLauncher``, ``MeleeSweep``) listens for ``fired`` and applies its ``effects`` to what it hits.

.. source-file:: ../../character_system/items/components/trigger.gd

.. source-file:: ../../character_system/items/components/magazine.gd

``rounds`` is a property with a getter and setter: reading it reads ``item.state``, and assigning it writes ``item.state`` and emits ``changed``. The rest of the code treats it like a normal variable.

.. _doc_hit_detection_and_hurtboxes:

Hit detection and hurtboxes
---------------------------

A :ref:`Hurtbox<class_Hurtbox>` is an optional ``Area3D`` on a character, such as a head. Hits on it count as hits on its character, scaled by its ``multiplier``. Characters without hurtboxes are hit through their own body collider, so nothing breaks if you skip them.

Shots are physics rays, so collision layers decide what they can hit. ``Hitscan.collision_mask`` lists the layers a weapon hits, every layer by default; untick layers in the inspector to make, for example, a rifle that ignores a turrets layer. The ray also hits areas, which is how hurtboxes get hit. :ref:`EffectZone<class_EffectZone>` therefore sets its own layer to 0, so shots and AI sight lines pass through fire patches and pools. A zone still detects bodies, because detection uses its mask, not its layer.

.. source-file:: ../../character_system/characters/hurtbox.gd

.. source-file:: ../../character_system/items/components/hitscan.gd

``ProjectileLauncher`` and ``MeleeSweep`` follow the :ref:`Hitscan<class_Hitscan>` pattern: require :ref:`Trigger<class_Trigger>`, listen to ``fired`` in ``_start()``, find targets, and build each context with ``Hurtbox.hit()``.

.. _doc_passives_from_equipment:

Passives from equipment
-----------------------

.. source-file:: ../../character_system/items/components/grant_statuses.gd

``drop_hold()`` drops one hold instead of removing the status outright. Two rings that grant Haste keep it until both are taken off. ``_granted`` remembers which passives were accepted, so an item whose passive was refused by an apply condition doesn't drop a hold that belongs to another item.

.. _doc_example_items:

Example items
-------------

.. list-table::
   :header-rows: 1

   * - Item
     - Components
     - Result
   * - Assault rifle
     - :ref:`Trigger<class_Trigger>` (automatic, 10 per second), :ref:`Magazine<class_Magazine>` (30, rifle ammo), :ref:`Hitscan<class_Hitscan>` [damage]
     - Full-auto, ammo-limited hitscan weapon
   * - Revolver
     - :ref:`Trigger<class_Trigger>` (2 per second), :ref:`Magazine<class_Magazine>` (6, pistol ammo), :ref:`Hitscan<class_Hitscan>` [damage]
     - Semi-auto, same scripts with different numbers
   * - Flaming sword
     - :ref:`Trigger<class_Trigger>` (1.5 per second), ``MeleeSweep`` [damage, apply Burning]
     - Melee weapon that sets targets on fire
   * - Storm rod
     - :ref:`Trigger<class_Trigger>`, :ref:`Hitscan<class_Hitscan>` [lightning damage, extra lightning damage if target has tag ``wet``]
     - Rewards combining with water, using a condition
   * - Healing staff
     - :ref:`Trigger<class_Trigger>`, :ref:`Hitscan<class_Hitscan>` [heal]
     - Same delivery, friendly effect
   * - Ring of haste
     - :ref:`GrantStatuses<class_GrantStatuses>` [Haste passive]
     - No trigger at all, only a passive
   * - Cursed rifle
     - Assault rifle + :ref:`GrantStatuses<class_GrantStatuses>` [Fragile passive]
     - A weapon and a passive drawback in one item
