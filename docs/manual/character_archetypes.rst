.. _doc_character_archetypes:

Character archetypes
====================

The three character kinds share one scene layout and differ in two components and their data.

.. code:: text

   Character (CharacterBody3D)
   ├── CollisionShape3D
   ├── Model (Node3D)
   │   ├── HandSocket (BoneAttachment3D)
   │   └── HeadHurtbox (Hurtbox, optional)  <- multiplier 2.0 for headshots
   ├── ComponentManager <- one per character; children can be in any order
   ├── Statuses
   ├── Health
   ├── Brain            <- PlayerBrain or AIBrain
   ├── Movement
   ├── Faction
   ├── Abilities
   ├── Inventory
   ├── Equipment
   └── WeaponSwitch     <- optional: carry several weapons, hold one

**Order doesn't matter.** Components register with the :ref:`ComponentManager<class_ComponentManager>` as they enter the tree, and none of them starts until the whole character is ready. :ref:`Health<class_Health>` stays full until every component has started, so innate passives such as "+20 max health" count wherever :ref:`Statuses<class_Statuses>` sits.

.. list-table::
   :header-rows: 1

   * - Component
     - Player
     - Hostile AI
     - Friendly AI
   * - :ref:`Brain<class_Brain>`
     - :ref:`PlayerBrain<class_PlayerBrain>`
     - :ref:`AIBrain<class_AIBrain>` + decision logic
     - :ref:`AIBrain<class_AIBrain>` + decision logic
   * - ``Faction.team``
     - ``player``
     - ``enemy``
     - ``ally``
   * - ``Faction.hostile_to``
     - ``enemy``
     - ``player``, ``ally``
     - ``enemy``
   * - :ref:`ComponentManager<class_ComponentManager>`, :ref:`Statuses<class_Statuses>`, :ref:`Health<class_Health>`, :ref:`Movement<class_Movement>`
     - Yes
     - Yes
     - Yes
   * - :ref:`MouseLook<class_MouseLook>`
     - Yes
     - No
     - No
   * - :ref:`Abilities<class_Abilities>`, :ref:`Equipment<class_Equipment>`
     - Yes
     - Yes
     - Yes
   * - WeaponSwitch
     - Yes
     - Optional
     - Optional
   * - :ref:`Inventory<class_Inventory>`
     - Yes
     - Optional, as a loot table
     - Optional
   * - ``Statuses.innate``
     - Class and race passives
     - Monster traits, e.g. fire immunity
     - Companion traits

**One base scene, many characters.** Build one character scene that holds the shared parts: the body, its collision shape, the ComponentManager, Statuses, Health, Movement and Inventory. Make the player, enemies and allies as inherited scenes of it (Scene > New Inherited Scene), each adding its brain and its camera or navigation agent, and setting its Faction. A change to the base, such as a new component every character should have, then reaches them all. The :ref:`quick start <doc_quick_start>` builds a player and a target by hand, and the recipe "Make an enemy that attacks" builds an AI.

A stationary turret is a character without :ref:`Movement<class_Movement>` and with a plain :ref:`Brain<class_Brain>`, driven by your own component. A destructible crate is a :ref:`ComponentManager<class_ComponentManager>` and a :ref:`Health<class_Health>` on a ``StaticBody3D``.
