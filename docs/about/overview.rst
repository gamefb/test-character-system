.. _doc_overview:

Overview
========

Every character, weapon and hazard in the game is a plain node with small component children, and every gameplay change passes through one effect pipeline. A player, a hostile AI and a friendly AI are the same scene with different components and data. A rifle and a magic ring are built the same way.

The document targets Godot 4.4 or later with GDScript, because the code uses typed dictionaries. It covers three systems that share one foundation:

-  **Characters**: stats, health, movement, input or AI, inventory, weapon switching, abilities and faction as separate components.
-  **Equipment**: items whose behavior comes from their components, such as fire rate, magazine and hit detection.
-  **Statuses and passives**: data-driven conditions that anything can apply to anything, in the style of Baldur's Gate 3, including conditions on effects, conditions on whether a status can be applied at all, and statuses that change damage before it lands.

.. _doc_design_rules:

Design rules
------------

1. **Compose, never inherit.** There is no ``Player`` or ``Enemy`` class. A character is whatever its components make it.
2. **Data in Resources, behavior in Nodes.** Designers create ``.tres`` files (statuses, abilities, items). Programmers write components once.
3. **Components find each other by type, through a hub.** Each host has one :ref:`ComponentManager<class_ComponentManager>`. Components register with it by themselves and look each other up through it, so there are no hard-coded node paths and no required root class. A component lists what it can't work without in ``_requires()``; until those parts are present it waits, with a warning in the editor, instead of crashing. A new kind of component never needs a change to the manager.
4. **One way to change gameplay state.** Damage, healing and statuses are all :ref:`Effect<class_Effect>` resources. Weapons, abilities, statuses and the environment all run the same effects.
5. **Numbers live on the component that uses them.** :ref:`Health<class_Health>` owns ``max_health`` and :ref:`Movement<class_Movement>` owns ``move_speed``. Statuses and items change them with modifiers, and readers ask for the current value at the moment of use.
6. **Everything is documented in the code.** Comments starting with ``##`` are documentation comments. Godot shows them in its built-in help (press F1 and search for a class name) and as tooltips on exported properties in the inspector.

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
