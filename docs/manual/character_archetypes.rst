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
   ├── Attributes       <- optional: strength, level and other stats of your own
   ├── Pool             <- optional, one per kind: mana, stamina, a shield
   ├── Brain            <- PlayerBrain or AIBrain
   ├── CharacterMotor   <- with WalkMode and AirMode under it
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
   * - :ref:`ComponentManager<class_ComponentManager>`, :ref:`Statuses<class_Statuses>`, :ref:`Health<class_Health>`, :ref:`CharacterMotor<class_CharacterMotor>`
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
   * - :ref:`Attributes<class_Attributes>`, :ref:`Pool<class_Pool>`
     - If the game has stats, mana or shields
     - The same; a boss might have a shield and a grunt none
     - The same
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

**One base scene, many characters.** Build one character scene that holds the shared parts: the body, its collision shape, the ComponentManager, Statuses, Health, CharacterMotor with its modes, and Inventory. Make the player, enemies and allies as inherited scenes of it (Scene > New Inherited Scene), each adding its brain and its camera or navigation agent, and setting its Faction. A change to the base, such as a new component every character should have, then reaches them all. The :ref:`quick start <doc_quick_start>` builds a player and a target by hand, and the recipe "Make an enemy that attacks" builds an AI.

**Different ways of moving.** The modes and moves under each character's CharacterMotor decide how it moves, so the inherited scenes can differ there too:

- A heavy enemy that can't double jump: set its AirMode's **Air Jumps** to 0.
- A nimble one: add a :ref:`DashMove<class_DashMove>` or a :ref:`WallSlideMode<class_WallSlideMode>` under its motor.
- A flying enemy: add your own flying mode (the recipe "Write your own movement mode or move" has one) and set the motor's **Start Mode** to it.
- An AI uses the same modes and moves as a player. :ref:`AIBrain<class_AIBrain>` fills ``move_dir`` from its path, and your decision logic jumps or dashes with ``brain.press(&"jump")`` and ``brain.release(&"jump")``, as :ref:`AttackNearest<class_AttackNearest>` does for firing.

**Different classes.** A warrior and a mage are the same scene with different data: the numbers on their :ref:`Attributes<class_Attributes>`, the :ref:`Pool<class_Pool>`\ s they have, their innate passives and the abilities in their slots. ``examples/characters/mage.tscn`` is a small one: 80 health, ``spell_power`` and ``crit_chance``, a mana pool that refills, a shield that recharges after three seconds out of combat, and a Fireball on ``secondary``.

A stationary turret is a character without a :ref:`CharacterMotor<class_CharacterMotor>` and with a plain :ref:`Brain<class_Brain>`, driven by your own component. A destructible crate is a :ref:`ComponentManager<class_ComponentManager>` and a :ref:`Health<class_Health>` on a ``StaticBody3D``.
