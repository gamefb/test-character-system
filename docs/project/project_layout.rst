.. _doc_project_layout:

Project layout and pitfalls
===========================

Everything lives in ``character_system/``, in three layers. Each one needs only the ones before it:

- ``core/`` is the rules everything shares: components, stats, events, effects, pools, health and statuses. It loads on its own.
- ``character/`` is the character framework: the scaffold a character and its gear are assembled on, built on the core the same way your own scripts will be. It has brains, the motor, abilities, inventory and equipment, weapon parts, zones, projectiles and the animation bridge. It decides how things work, not what is in the game. Use its parts, change them, or delete the ones your game doesn't need.
- ``starter_pack/`` is what a player sees and uses, made with the two layers above: statuses, items, abilities, zones, projectiles and a character, and the scripts for particular features, such as walking, dashing and sprinting. Duplicate what you want and delete the rest; nothing in ``core/`` or ``character/`` needs it.

Your own data and scenes stay outside all three, so the system can be copied to another project as one folder. Each script file holds one ``class_name``.

.. code:: text

   res://
   ├── addons/
   │   └── character_system_warnings/  name warnings above the Inspector
   ├── character_system/
   │   ├── RECIPES.md                one-page answers to "how do I…"
   │   ├── icons/                    editor icons, one per node type
   │   ├── core/                     the rules: 22 scripts, keep all of them
   │   │   ├── component.gd          the base class of every component
   │   │   ├── component_manager.gd  add one to every host; stats, events and blocks
   │   │   ├── effect_context.gd     who did what to whom
   │   │   ├── world_events.gd       hears every host's events
   │   │   ├── pool.gd               an amount that is spent and refilled
   │   │   ├── health.gd             the pool named health; resistances and death
   │   │   ├── name_check.gd         finds mistyped stat, event, tag, pool and block names
   │   │   ├── stats/                stat_modifier
   │   │   ├── effects/              effect and amount_effect (bases), damage, heal,
   │   │   │                         apply_status, remove_status, modify_amount
   │   │   ├── conditions/           condition (base), has_tag
   │   │   ├── amounts/              amount (base), stat_amount
   │   │   └── statuses/             statuses, status_data, status_trigger, dead.tres
   │   ├── character/                the framework: 44 scripts, keep what you use
   │   │   ├── brains/               brain, player_brain, ai_brain, mouse_look
   │   │   ├── motor/                character_motor, motor_node, movement_mode (base),
   │   │   │                         layered_move (base)
   │   │   ├── combat/               hurtbox, faction
   │   │   ├── abilities/            abilities, ability_data, targeting, radius_targeting
   │   │   ├── items/                item_data, item_instance, item_component, inventory,
   │   │   │                         equipment, weapon_switch, trigger, magazine,
   │   │   │                         weapon_delivery (base), hitscan, melee_sweep, grants
   │   │   ├── world/                effect_zone, projectile
   │   │   ├── animation/            animator
   │   │   ├── effects/              knockback, spawn_scene, launch_projectile, change_pool
   │   │   ├── conditions/           pool_below, stat, is_hostile, chance, hit, any, charge
   │   │   └── amounts/              pool, hit, random, charge
   │   └── starter_pack/             what a player sees and uses: copy what you want
   │       ├── statuses/, traits/    Burning, Stunned, Vampiric, Undead and the rest
   │       ├── items/                item data, with their scenes in items/scenes/
   │       ├── abilities/, zones/, projectiles/, characters/
   │       └── scripts/              9 scripts: walk_mode, air_mode, dash_move, glide_move,
   │                                 wall_slide_mode, sprint, scope, attack_nearest,
   │                                 character_hud
   ├── data/                         your .tres files
   ├── scenes/                       your characters, items and levels
   ├── tests/                        test_*.gd, run with GUT; benchmark.gd
   ├── test_level/                   a playable level with every part in it
   └── immunity_test/                scripted checks: immunities, zones, items

**What the character folders need.** Every script in ``character/`` needs the core. Some also need another folder of ``character/``, which matters when you delete or replace one:

.. list-table::
   :header-rows: 1

   * - Folder
     - Also needs
   * - ``brains/``
     - ``combat/`` (the player's aim ignores its own :ref:`Hurtbox<class_Hurtbox>`\ es)
   * - ``motor/``
     - ``brains/``. It has no modes of its own: add the starter pack's, or yours
   * - ``combat/``
     - Nothing
   * - ``abilities/``
     - ``brains/`` and ``combat/``
   * - ``items/``
     - ``brains/`` and ``combat/``; :ref:`Grants<class_Grants>` needs ``abilities/``, and :ref:`Hitscan<class_Hitscan>` needs ``world/``
   * - ``world/``
     - ``combat/``
   * - ``animation/``
     - Nothing
   * - ``effects/``, ``conditions/``, ``amounts/``
     - One thing each at most: knockback needs ``motor/``, launching a projectile needs ``brains/`` and ``world/``, and the hostility check needs ``combat/``

So a game with its own movement deletes ``motor/`` and the knockback effect, and a game with its own inventory replaces ``items/``. CI checks the layering on every pull request: it loads every script of ``core/`` with the other two folders deleted, and every script of ``core/`` and ``character/`` with ``starter_pack/`` deleted.

**Base classes are abstract.** :ref:`Component<class_Component>`, :ref:`Effect<class_Effect>`, :ref:`Condition<class_Condition>`, :ref:`Amount<class_Amount>`, :ref:`Targeting<class_Targeting>`, :ref:`ItemComponent<class_ItemComponent>`, :ref:`MotorNode<class_MotorNode>`, :ref:`MovementMode<class_MovementMode>` and :ref:`LayeredMove<class_LayeredMove>` are marked ``@abstract``, so nobody adds one as a node or creates one as a resource by mistake, and Godot reports an effect, amount or targeting script that forgot the one method it must write. This needs Godot 4.5 or newer; the project is developed on 4.8.

**The starter pack and the recipes.** ``starter_pack/`` holds working resources to duplicate and change: statuses (Burning, Poisoned, Wet, Regenerating, Warded, Haste, Rooted, Thorns, Fireproof, Stunned, Silenced, Vampiric, Bloodlust, Fire ward, Sharpshooter, Lucky strikes, Executioner, Berserk, Bleeding, Drawing; the Dead status itself is in ``core/statuses/``), traits (Undead, Construct), items with their scenes (rifle, rifle ammo, flare gun, shotgun, marksman rifle, soldier rifle, rocket launcher, rockets, longbow, sword, fire staff, fireproof cloak, ward amulet, ring of vigor, health potion, mana potion, grenade), zones (fire patch, water pool, healing pad, ward circle, poison bog), abilities (Second Wind, Sprint, Fireball, Shockwave), projectiles (the fireball, a rocket, a grenade, an arrow) and a character (a mage with stats of her own, mana and a shield). ``starter_pack/scripts/`` holds scripts to copy: a :ref:`Sprint<class_Sprint>` component that spends from a pool, a :ref:`Scope<class_Scope>` item component, :ref:`AttackNearest<class_AttackNearest>` AI decision logic, a :ref:`CharacterHud<class_CharacterHud>`, a :ref:`WallSlideMode<class_WallSlideMode>` movement mode and a :ref:`GlideMove<class_GlideMove>` layered move, all explained in :ref:`doc_extending`. ``RECIPES.md`` answers the common jobs on one page, from making a character, status, weapon or zone to reading buttons and showing health on screen, and points at the matching example. ``test_level/test_level.tscn`` puts all of it in one level to walk around in; see :ref:`doc_test_level`.

**Editor icons.** Every node type has its own icon file in ``icons/``, set by an ``@icon(...)`` line above its ``class_name``. Most are still the same plain square; the motor, its modes and moves, and :ref:`WeaponSwitch<class_WeaponSwitch>` have a symbol of their own. To give a node type its own icon, replace its SVG; the ``@icon`` line doesn't change. A script without its own ``@icon`` shows its base class's icon, so your own components look like components, and effects, conditions and targeting resources keep their base class's icon in the Inspector.

To build the system yourself, one stage at a time, see :ref:`doc_build_from_scratch`.

.. _doc_pitfalls:

Pitfalls
--------

-  **Do not store stat values.** Read them with ``stat()`` at the moment of use, or listen to the manager's ``stat_changed``. A stored speed ignores every status.
-  **Call ``update_stats()`` after changing your own number.** Totals are cached, so a component that changes a number its ``_stats()`` returns must say so. The built-in exports do it in their setters.
-  **Reach other nodes in ``_start()``, not ``_ready()``.** ``_start()`` runs only once everything in ``_requires()`` is present, and never in the editor. In a ``@tool`` script, ``_ready()`` also runs in the editor.
-  **Resources are shared.** A :ref:`StatusData<class_StatusData>`, :ref:`ItemData<class_ItemData>` or :ref:`Effect<class_Effect>` is one object used by every character. Keep runtime state in ``ItemInstance.state``, ``ActiveStatus`` or a component, never in an exported field of a definition resource.
-  **Passives from items and zones need duration 0.** Holds are only counted for permanent statuses, so a timed status granted by :ref:`Grants<class_Grants>` doesn't lose a hold on unequip; it simply runs out.
-  **Apply conditions are checked once.** A status that was allowed stays even if its conditions later stop being true; end it with an effect or trigger if it should. An item passive that was refused is not retried until the item is equipped again.
-  **Keep ``react_to_statuses`` for amount changes.** A trigger that deals damage with this flag on bounces between two characters until the chain is cut at ``EffectContext.MAX_DEPTH`` triggers, with a warning in the Output panel.
-  **Change a hit through its totals.** In ``dealing_damage`` and ``taking_damage``, add to ``ctx.add``, ``ctx.percent`` and ``ctx.mul``. Editing ``ctx.amount`` there still works, but the result then depends on which listener ran first. In ``absorbing_damage`` the number is final, and lowering ``ctx.amount`` is the way.
-  **Chance conditions roll each time they're checked.** One on each of a trigger's effects rolls separately for each. Put it in the trigger's own ``conditions`` to roll once.
-  **A stat must be listed before the warnings know it.** A stat in a :ref:`ComponentManager<class_ComponentManager>`'s Stats, or a :ref:`Pool<class_Pool>`'s name, is known to the editor warnings once a saved scene has it. Until then a modifier on it is flagged, though it works.
-  **Events are signals, so listeners clean up after themselves.** A method connected to ``event()`` or ``WorldEvents.event()`` is dropped when its object is freed, and so is a lambda that uses the object it was written in. A lambda that uses nothing of its object stays connected until ``disconnect()``.
-  **Costs need a pool of that name.** An ability whose ``costs`` name a pool the character doesn't have can never be used; ``why_not()`` answers ``cost``.
-  **Sources can die.** A status may outlive the character that applied it, and a rocket whoever fired it. A context built after that has a null ``source``, and ``Component.of``, ``ComponentManager.of``, ``stat_of`` and ``notify`` accept a freed node. GDScript refuses a freed node for a typed parameter, so your own functions that may be handed one should leave that parameter untyped, and custom effects must check ``is_instance_valid(ctx.source)`` before using it directly.
-  **Friendly fire is a rule, not a system.** If allies should not hurt each other, add a :ref:`Condition<class_Condition>` that checks ``Faction.is_hostile`` and put it on weapon damage effects.
-  **Connect with ``listen()``, and hear events with ``on()``.** Both are undone when the component stops, which is what makes "unequip is free" and removing components mid-game safe. A plain ``connect()`` to another node stays until one of them is freed.
-  **Your own components need ``@tool`` for editor warnings.** Without it they still work, and problems are reported in the Output panel when the game runs. With it, keep editor-only care in mind: the base class turns processing off in the editor, but your own ``_ready()`` still runs there.
-  **Areas on a weapon's layers block its shots.** Rays hit areas so that hurtboxes work, so a trigger volume or pickup on a layer in the weapon's mask stops the shot. Put such areas on no layer, as :ref:`EffectZone<class_EffectZone>` does, or on a layer your weapons leave out.
-  **An AI that has a path but stands still.** A navigation mesh baked from colliders sits a little above the floor (0.5 m for a default bake). If the agent's Path Height Offset doesn't match, the next waypoint can be straight above the character, so :ref:`AIBrain<class_AIBrain>` has no direction to walk. Set Path Height Offset to the mesh's height above the floor; the enemy template already does.
-  **A press from code lands next frame.** ``brain.press()`` counts from the next frame, so every node sees it exactly once. A script that presses a button and checks the result straight away has to wait a frame first.
