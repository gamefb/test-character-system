.. _doc_project_layout:

Project layout and pitfalls
===========================

All scripts live in ``character_system/``, grouped by where they are used, and every base class sits in a ``_base/`` folder. Your own data and scenes stay outside it, so the system can be copied to another project as one folder. Each script file holds one ``class_name``.

.. code:: text

   res://
   ├── addons/
   │   └── character_system_warnings/  name warnings above the Inspector
   ├── character_system/
   │   ├── RECIPES.md                one-page answers to "how do I…"
   │   ├── icons/                    editor icons, one per node type
   │   ├── examples/                 statuses, traits, items, zones, abilities and scripts
   │   │                             to copy
   │   ├── core/                     the framework
   │   │   ├── _base/component.gd
   │   │   ├── component_manager.gd  add one to every host
   │   │   ├── effect_context.gd
   │   │   └── name_check.gd         finds mistyped stat, event and tag names
   │   ├── characters/               add to character scenes
   │   │   ├── components/           statuses, health, mouse_look, faction, inventory,
   │   │   │                         abilities, equipment, weapon_switch
   │   │   ├── motor/                character_motor, walk_mode, air_mode, dash_move
   │   │   │   └── _base/            motor_node, movement_mode, layered_move
   │   │   ├── brains/
   │   │   │   ├── _base/brain.gd
   │   │   │   ├── player_brain.gd
   │   │   │   └── ai_brain.gd
   │   │   └── hurtbox.gd
   │   ├── items/                    add to item scenes
   │   │   └── components/           trigger, magazine, hitscan, melee_sweep, grant_statuses
   │   │       └── _base/item_component.gd
   │   ├── world/                    add to levels
   │   │   └── effect_zone.gd
   │   └── resources/                create as .tres files
   │       ├── stats/                stat_modifier
   │       ├── items/                item_data, item_instance
   │       ├── statuses/             status_data, status_trigger
   │       ├── abilities/            ability_data, targeting/_base/targeting.gd,
   │       │                         targeting/radius_targeting
   │       ├── effects/              _base/effect.gd, damage, heal, knockback,
   │       │                         apply_status, remove_status, modify_amount, spawn_scene
   │       └── conditions/           _base/condition.gd, has_tag, health_below, stat,
   │                                 is_hostile
   ├── data/                         your .tres files
   ├── scenes/                       your characters, items and levels
   ├── tests/                        test_*.gd, run with GUT
   └── immunity_test/                scripted checks: immunities, zones, items

**Examples and recipes.** ``examples/`` holds working resources to duplicate and change: statuses (Burning, Poisoned, Wet, Regenerating, Warded, Haste, Rooted, Thorns, Fireproof), traits (Undead, Construct), items with their scenes (rifle, rifle ammo, flare gun, fireproof cloak, ward amulet), zones (fire patch, water pool, healing pad, ward circle, poison bog) and abilities (Second Wind, Sprint). ``examples/scripts/`` holds scripts to copy: a :ref:`Stamina<class_Stamina>` component, a :ref:`Scope<class_Scope>` item component, :ref:`AttackNearest<class_AttackNearest>` AI decision logic, a :ref:`CharacterHud<class_CharacterHud>`, a :ref:`WallSlideMode<class_WallSlideMode>` movement mode and a :ref:`GlideMove<class_GlideMove>` layered move, all explained in :ref:`doc_extending`. ``RECIPES.md`` answers the common jobs on one page, from making a character, status, weapon or zone to reading buttons and showing health on screen, and points at the matching example.

**Editor icons.** Every node type has its own icon file in ``icons/``, set by an ``@icon(...)`` line above its ``class_name``. Most are still the same plain square; the motor, its modes and moves, and :ref:`WeaponSwitch<class_WeaponSwitch>` have a symbol of their own. To give a node type its own icon, replace its SVG; the ``@icon`` line doesn't change. A script without its own ``@icon`` shows its base class's icon, so your own components look like components, and effects, conditions and targeting resources keep their base class's icon in the Inspector.

To build the system yourself, one stage at a time, see :ref:`doc_build_from_scratch`.

.. _doc_pitfalls:

Pitfalls
--------

-  **Do not store stat values.** Read them with ``stat()`` at the moment of use, or listen to the manager's ``stat_changed``. A stored speed ignores every status.
-  **Call ``update_stats()`` after changing your own number.** Totals are cached, so a component that changes a number its ``_stats()`` returns must say so. The built-in exports do it in their setters.
-  **Reach other nodes in ``_start()``, not ``_ready()``.** ``_start()`` runs only once everything in ``_requires()`` is present, and never in the editor. In a ``@tool`` script, ``_ready()`` also runs in the editor.
-  **Resources are shared.** A :ref:`StatusData<class_StatusData>`, :ref:`ItemData<class_ItemData>` or :ref:`Effect<class_Effect>` is one object used by every character. Keep runtime state in ``ItemInstance.state``, ``ActiveStatus`` or a component, never in an exported field of a definition resource.
-  **Passives from items and zones need duration 0.** Holds are only counted for permanent statuses, so a timed status granted by :ref:`GrantStatuses<class_GrantStatuses>` doesn't lose a hold on unequip; it simply runs out.
-  **Apply conditions are checked once.** A status that was allowed stays even if its conditions later stop being true; end it with an effect or trigger if it should. An item passive that was refused is not retried until the item is equipped again.
-  **Keep ``react_to_statuses`` for amount changes.** A trigger that deals damage with this flag on can bounce between two characters forever.
-  **Sources can die.** A status may outlive the character that applied it. ``Component.of`` and ``ComponentManager.stat_of`` already tolerate a freed node; custom effects must check ``is_instance_valid(ctx.source)`` before using it directly.
-  **Friendly fire is a rule, not a system.** If allies should not hurt each other, add a :ref:`Condition<class_Condition>` that checks ``Faction.is_hostile`` and put it on weapon damage effects.
-  **Connect with ``listen()``.** Connections made with it are undone when the component stops, which is what makes "unequip is free" and removing components mid-game safe. A plain ``connect()`` to another node stays until one of them is freed.
-  **Your own components need ``@tool`` for editor warnings.** Without it they still work, and problems are reported in the Output panel when the game runs. With it, keep editor-only care in mind: the base class turns processing off in the editor, but your own ``_ready()`` still runs there.
-  **Areas on a weapon's layers block its shots.** Rays hit areas so that hurtboxes work, so a trigger volume or pickup on a layer in the weapon's mask stops the shot. Put such areas on no layer, as :ref:`EffectZone<class_EffectZone>` does, or on a layer your weapons leave out.
-  **An AI that has a path but stands still.** A navigation mesh baked from colliders sits a little above the floor (0.5 m for a default bake). If the agent's Path Height Offset doesn't match, the next waypoint can be straight above the character, so :ref:`AIBrain<class_AIBrain>` has no direction to walk. Set Path Height Offset to the mesh's height above the floor; the enemy template already does.
-  **A press from code lands next frame.** ``brain.press()`` counts from the next frame, so every node sees it exactly once. A script that presses a button and checks the result straight away has to wait a frame first.
