.. _doc_overview:

Overview
========

Every character, weapon and hazard in the game is a plain node with small component children, and every gameplay change passes through one effect pipeline. A player, a hostile AI and a friendly AI are the same scene with different components and data. A rifle and a magic ring are built the same way.

The document targets Godot 4.8 with GDScript; the code uses typed dictionaries and ``@abstract`` classes, so it needs 4.5 at the least. It comes in three layers. The **core** (``core/``) is the rules everything shares: components, stats, events, effects, pools, health and statuses. It loads on its own. The **character framework** (``character/``) is the scaffold a character and its gear are assembled on, such as brains, the motor, abilities, inventory, weapon parts and timing for animations, which you can keep, change or replace with your own. The **starter pack** (``starter_pack/``) is what a player sees and uses: particular statuses, items, abilities, ways of moving and characters, ready to copy. It covers three systems that share one foundation:

-  **Characters**: stats, health, pools such as mana and shields, movement, input or AI, inventory, weapon switching, abilities and faction as separate components.
-  **Equipment**: items whose behavior comes from their components, such as fire rate, magazine, hit detection, projectiles, stat bonuses and granted abilities.
-  **Statuses and passives**: data-driven conditions that anything can apply to anything, in the style of Baldur's Gate 3, including conditions on effects, conditions on whether a status can be applied at all, and statuses that change damage before it lands.

Most new content is data. A weapon that scales with strength, a spell with a mana cost and a cast time, a crit passive, a ring with random bonuses and a stun are all built in the Inspector from parts that already exist; :ref:`doc_ability_status_or_component` shows where each kind of idea goes.

.. _doc_design_rules:

Design rules
------------

1. **Compose characters, never inherit them.** There is no ``Player`` or ``Enemy`` class. A character is whatever its components make it. Base classes are kept for parts of one kind that would otherwise repeat the same fields: every effect with a number extends :ref:`AmountEffect<class_AmountEffect>`, and every way a weapon hits extends :ref:`WeaponDelivery<class_WeaponDelivery>`, so a new one is a few lines.
2. **Data in Resources, behavior in Nodes.** Designers create ``.tres`` files (statuses, abilities, items). Programmers write components once.
3. **Components find each other by type, through a hub.** Each host has one :ref:`ComponentManager<class_ComponentManager>`. Components register with it by themselves and look each other up through it, so there are no hard-coded node paths and no required root class. A component lists what it can't work without in ``_requires()``; until those parts are present it waits, with a warning in the editor, instead of crashing. A new kind of component never needs a change to the manager.
4. **One way to change gameplay state.** Damage, healing and statuses are all :ref:`Effect<class_Effect>` resources. Weapons, abilities, statuses and the environment all run the same effects.
5. **Numbers live on the component that uses them.** :ref:`Health<class_Health>`, a pool, owns ``max_health`` and :ref:`CharacterMotor<class_CharacterMotor>` owns ``move_speed``. Statuses and items change them with modifiers, and readers ask for the current value at the moment of use.
6. **Changes add up the same way everywhere.** A stat and a hit are both worked out as (base + adds) × (1 + percents) × muls, from totals that are collected first and applied once. The result never depends on which status or item came first.
7. **Intent has one source.** Everything a character does starts from its :ref:`Brain<class_Brain>`, so a player and an AI use the same weapons and abilities, and a stun or a death stops all of them in one place.
8. **Everything is documented in the code.** Comments starting with ``##`` are documentation comments. Godot shows them in its built-in help (press F1 and search for a class name) and as tooltips on exported properties in the inspector.

.. _doc_godot_terms_used_in_this_document:

Godot terms used in this document
---------------------------------

.. list-table::
   :header-rows: 1

   * - Term
     - Meaning
   * - Node
     - An object in the scene tree. Components are nodes.
   * - Resource
     - A data object saved as a ``.tres`` file and edited in the inspector. Statuses, items and effects are resources.
   * - ``class_name``
     - Registers a script as a global type, so it can be used in code and picked in the inspector.
   * - ``@export``
     - Shows a variable in the inspector so designers can set it.
   * - ``@tool``
     - Runs a script in the editor too. Built-in components use it only to show warnings.
   * - ``_notification()``
     - Called for every engine event (entering the tree, ready, leaving). Unlike ``_ready()``, it runs for every script in the inheritance chain.
   * - Signal
     - An event a node announces, e.g. ``died``. Other nodes ``connect`` a function to it.
   * - :ref:`StringName<class_StringName>`
     - A fast, unique string written ``&"name"``. Used for stat, slot, tag and action names.

Where to go next
----------------

Build the :ref:`quick start <doc_quick_start>` level to see the parts working together, then use the :ref:`recipes <doc_recipes>` for everyday jobs. When you need code of your own, :ref:`doc_extending` explains where new gameplay belongs and shows a complete example of each kind of script.
