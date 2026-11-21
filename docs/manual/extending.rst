.. _doc_extending:

Extending the system
====================

Most new gameplay needs no new code: a status, an ability or an item made of the existing parts in the Inspector. This page is for when it does. It starts with how to decide where an idea belongs, then shows one complete script of each kind you can add. Every script here is a real file in the project, covered by ``tests/test_extending.gd``, so you can use it as it is or copy it as a starting point.

.. _doc_ability_status_or_component:

Ability, status, effect or component?
-------------------------------------

New gameplay usually fits one of these places:

- An **ability** is one action that happens once per press, then cools down.
- A **status** changes numbers and reacts to events, for a while or as long as something holds
  it.
- An **effect** is one instant change to a target, such as damage or a knockback. Abilities,
  statuses, weapons and zones all run effects, so a new one works in all four.
- A **component** is ongoing behaviour with its own memory, running every frame. On an item,
  it's an **item component**.

To place a new idea, ask in this order:

1. Does it happen once per press, then cool down? Make it an **ability**.
2. Does it change a number, or react to hits or deaths, for a while or while equipped? Make it a
   **status**, which an ability, item or zone can apply.
3. Is the missing piece one instant change, such as "spawn a puddle"? Write an **effect** and
   use it in an ability or status.
4. Does it need memory between frames or presses, a held button, or a change to how the
   character moves or acts? Make it a **component**.

.. list-table::
   :header-rows: 1
   :widths: 20 40 40

   * -
     - Good at
     - Limits
   * - Ability
     - One-off actions such as a heal, a fireball, a dash or applying a buff. Built in the
       Inspector with no code when the effects exist. Granted or removed during play by
       changing ``slots``; AI calls ``use()``.
     - Fires only on a fresh press: nothing while held, on release, charged or channelled. A
       cooldown is its only cost: no charges, mana, cast time or interruption. Effects are
       instant, so anything lasting goes through a status. It remembers nothing between uses
       but its cooldown. Conditions sit on the effects, so a failed one skips its effect but
       still spends the cooldown.
   * - Status
     - Stat changes, reactions to events (shields, thorns, burning), immunities and passives.
       Built in the Inspector. Timed, stacked, or held by items and zones.
     - Can't read buttons or run every frame, except ticks at ``tick_interval``. Only changes
       numbers some component already owns.
   * - Effect
     - Instant changes that every source can use. A few lines of code.
     - Remembers nothing: the resource is shared, so per-use values go in the context.
   * - Component
     - Anything that runs every frame, remembers state, reads held buttons, owns stats that
       statuses can change, or needs other components.
     - Needs GDScript and the start and stop lifecycle. Added to each character's scene, so
       designers can't mix and match them as freely as resources. No built-in cooldowns or
       costs.

Some examples:

.. list-table::
   :header-rows: 1
   :widths: 30 20 50

   * - Idea
     - Where
     - Why
   * - Double jump
     - Component
     - Remembers jumps left, checks the floor every frame and shares the jump button with
       :ref:`Movement<class_Movement>`. See :ref:`doc_double_jump`.
   * - Learning to double jump, or boots that grant it
     - Status
     - Adds 1 to the ``air_jumps`` stat that :ref:`DoubleJump<class_DoubleJump>` owns.
   * - Dash
     - Ability
     - Once per press: a :ref:`KnockbackEffect<class_KnockbackEffect>` on the user, then a
       cooldown.
   * - Sprint for a few seconds
     - Ability
     - Once per press: applies a speed status (``examples/abilities/sprint.tres`` applies
       Haste).
   * - Sprint while a button is held, with stamina
     - Component
     - Reads a held button every frame and remembers stamina. See :ref:`doc_extending_component`.
   * - A water spell that leaves a puddle
     - Ability + effect
     - Once per press, and the puddle is one instant change: :ref:`SpawnSceneEffect<class_SpawnSceneEffect>`.
   * - Hover while holding jump
     - Component
     - Runs every frame while a button is held.

When new behaviour needs code, prefer a new :ref:`Effect<class_Effect>` over a new component where you can: one effect works in abilities, statuses, weapons and zones at once. Most of the grey area comes from the ability limits above. A spell with charges, a mana cost or a charge-up can't be an ability yet, so today it would be a component of its own.

.. _doc_extending_checklist:

Before you write a script
-------------------------

- **Give it a** ``class_name``. Components then appear in the Add Node dialog, and effects,
  conditions and targeting in the Inspector's resource lists.
- **Do setup in** ``_start()``, **not** ``_ready()``. ``_start()`` runs once everything in
  ``_requires()`` is present, and never in the editor. Undo in ``_stop()`` whatever ``listen()``
  doesn't undo for you: stat modifiers, groups, spawned nodes.
- **Look things up when you need them.** ``find(Type)`` for a component beside yours,
  ``Component.of(node, Type)`` for one on another node. Both are cheap, so don't keep the
  result in a variable: components can come and go during play.
- **Read numbers with** ``stat()`` **at the moment you use them.** Numbers statuses should be
  able to change go in your component's ``_stats()``; call ``update_stats()`` when you change
  one yourself.
- **Resources are shared.** One effect, condition, status or item resource is used by every
  character at once, so it must not remember anything between uses. Per-use values go in the
  :ref:`EffectContext<class_EffectContext>`, per-character state in a component, and an item's
  own state, such as rounds loaded, in ``item.state``.
- **Cope with what isn't there.** An effect can hit a wall and a condition can check a crate,
  so check for null after every ``Component.of()``.
- **Add** ``@tool`` **to components for editor warnings.** The base class turns processing off
  in the editor and never calls ``_start()`` there, but your own ``_ready()`` would still run,
  which is one more reason to set up in ``_start()``. The
  :ref:`editor warnings <doc_editor_warnings_for_names>` also learn the stat names in your
  ``_stats()`` and the events you ``notify()``.

The :ref:`pitfalls <doc_pitfalls>` list the mistakes that are easiest to make.

.. _doc_extending_component:

A component
-----------

:ref:`Stamina<class_Stamina>` lets a character sprint while a button is held, using up stamina that comes back when it's let go.

.. source-file:: ../../character_system/examples/scripts/stamina.gd

Each part does one job:

- ``_requires()`` returns ``[Brain, Movement]``, so the component waits, with a warning, until
  both are beside it. Sprinting means nothing without movement.
- ``_stats()`` owns ``max_stamina``, so a status can raise it with a
  :ref:`StatModifier<class_StatModifier>` and ``stat(&"max_stamina")`` returns the result. The
  setter calls ``update_stats()``, so a change in the Inspector during play counts at once.
- ``_process()`` only runs while the component runs, so it can use the Brain without a null
  check. It reads the button with ``is_action_pressed()``, which stays true while it's held.
- The speed boost is a stat modifier added to the manager, so it combines with every other
  speed change, such as Wet slowing the character down. ``_stop()`` takes it off, so removing
  the component mid-sprint leaves nothing behind.
- The ``changed`` signal is for a stamina bar.

To use it, add it to a character beside Movement, add a ``sprint`` action to the Input Map, and add ``sprint`` to the :ref:`PlayerBrain<class_PlayerBrain>`'s Extra Actions.

.. _doc_extending_item_component:

An item component
-----------------

Item components extend :ref:`ItemComponent<class_ItemComponent>`, which adds ``wielder`` (the character holding the item), ``item`` (this copy of it) and ``brain`` (the wielder's brain). There are two common kinds.

**One that acts when the item is used** listens to the item's :ref:`Trigger<class_Trigger>`, which decides when it fires. :ref:`MeleeSweep<class_MeleeSweep>` hits everything inside a shape in front of the item:

.. source-file:: ../../character_system/items/components/melee_sweep.gd

- ``_requires()`` returns ``[Trigger]``, and ``_start()`` listens to its ``fired`` signal.
- The wielder's body and hurtboxes are collected once, in ``_start()``, so swings pass through
  them.
- ``Hurtbox.hit()`` builds each hit's context: it turns a hurtbox into its character, applies
  its multiplier, and records the item as ``origin``.
- The effects come from the Inspector, so the same component makes a sword, a burning axe or a
  healing touch.

To make a sword, build an item scene with a :ref:`ComponentManager<class_ComponentManager>`, a Trigger and a MeleeSweep with a BoxShape3D about a metre across and a :ref:`DamageEffect<class_DamageEffect>` in its effects. A projectile weapon would follow the same pattern: on ``fired``, spawn a projectile scene, give it the effects, and have it apply them to what it touches.

**One that changes the wielder while equipped** finds what it needs in ``_start()`` and undoes everything in ``_stop()``, which runs on unequip. :ref:`Scope<class_Scope>` zooms the wielder's camera and slows it down while the aim button is held:

.. source-file:: ../../character_system/examples/scripts/scope.gd

Whatever an item changes on its wielder must be undone in ``_stop()``. A stat modifier left on the wielder's manager would slow the character for the rest of the game.

.. _doc_extending_effect:

An effect
---------

An effect extends :ref:`Effect<class_Effect>` and overrides ``_execute(ctx)``. :ref:`SpawnSceneEffect<class_SpawnSceneEffect>` spawns a scene, such as a puddle or an explosion, where the target is:

.. source-file:: ../../character_system/resources/effects/spawn_scene_effect.gd

- Its numbers are ``@export`` variables, so each use is set up in the Inspector.
- ``ctx.target`` is whoever it happens to, and may be anything: a character, a crate or null.
  It checks before using it.
- It adds the scene with ``call_deferred()``, because effects can run inside physics callbacks
  such as a zone's ``body_entered``, where new areas can't be added yet.
- It stores nothing on itself between uses.

Conditions work on every effect without any code: put one in its ``conditions`` and the effect only runs when it passes. Effects that deal damage should scale by ``ctx.magnitude``, so status stacks and headshots strengthen them, as :ref:`DamageEffect<class_DamageEffect>` does.

To make a water spell, give an ability two effects: an :ref:`ApplyStatusEffect<class_ApplyStatusEffect>` with Wet, and a SpawnSceneEffect with ``examples/zones/water_pool.tscn`` and a lifetime of 10 seconds.

.. _doc_extending_condition:

A condition
-----------

A condition extends :ref:`Condition<class_Condition>`. Most override ``_test(node)``, which checks one side; ``subject`` picks which side and ``negate`` flips the answer, with no code of your own. The :ref:`Condition<class_Condition>` reference shows one. A condition that compares both sides overrides ``check(ctx)`` instead, like :ref:`IsHostileCondition<class_IsHostileCondition>`:

.. source-file:: ../../character_system/resources/conditions/is_hostile_condition.gd

Put it in the ``conditions`` of a weapon's DamageEffect to turn friendly fire off: allies are still hit, but take no damage.

.. _doc_extending_targeting:

Ability targeting
-----------------

An ability's ``targeting`` decides who its effects reach. Left empty, it's the user. :ref:`RadiusTargeting<class_RadiusTargeting>` picks everything within a radius:

.. source-file:: ../../character_system/resources/abilities/targeting/radius_targeting.gd

- ``find(ctx)`` gets the user as ``ctx.source`` and returns the targets.
- It asks the physics engine what's inside a sphere, through the user's world. A resource
  isn't in the scene itself, so it reaches the world through a node it's given.
- A hurtbox counts as its character, and each character is returned once.
- With ``hostile_only``, the user's :ref:`Faction<class_Faction>` filters out allies.

To make a shockwave, make an :ref:`AbilityData<class_AbilityData>` with a RadiusTargeting (radius 4), a DamageEffect and a :ref:`KnockbackEffect<class_KnockbackEffect>`, and put it in the character's Abilities slots. The :ref:`Targeting<class_Targeting>` reference shows one that hits what the user aims at.

.. _doc_extending_ai:

AI decision logic
-----------------

:ref:`AIBrain<class_AIBrain>` walks toward a target and aims at it, but doesn't choose one. That's the job of a component beside it. :ref:`AttackNearest<class_AttackNearest>` picks the nearest enemy every half second and taps the fire button while it's in range:

.. source-file:: ../../character_system/examples/scripts/attack_nearest.gd

- It only sets ``target`` and presses buttons, exactly as a player would, so every weapon and
  ability works for it.
- It decides a few times a second, not every frame: finding the nearest enemy is a search.
- Enemies come from :ref:`Faction<class_Faction>`: every character is in the Godot group of its
  team, so ``get_nodes_in_group()`` lists them.
- It attacks a target only once it has had it for one decision, which gives the brain time to
  aim and the AI a human-like reaction time.

The recipe "Make an enemy that attacks" sets one up. A turret works the same way with a plain :ref:`Brain<class_Brain>`: a component sets its ``aim_point`` and taps its buttons.

.. _doc_extending_hud:

A HUD
-----

:ref:`CharacterHud<class_CharacterHud>` shows a character's health, statuses, ammo and an ability's cooldown. Health and statuses are shown when their ``changed`` signals fire; ammo and the cooldown are read every frame, which is cheap.

.. source-file:: ../../character_system/examples/scripts/character_hud.gd

.. _doc_extending_names:

New stats, damage types, events and actions
-------------------------------------------

None of these need a change to the system:

- **A stat** is any name a component returns from ``_stats()``, such as ``max_stamina``.
  Statuses change it with a :ref:`StatModifier<class_StatModifier>` of the same name, and the
  component reads it with ``stat()``.
- **A damage type** is any name in :ref:`DamageEffect<class_DamageEffect>`'s ``type``, such as
  ``lightning``. Resistance to it is the ``resist_lightning`` stat: add it to
  :ref:`Health<class_Health>`'s resistances, or give it to a status as a modifier.
- **An event** is any name sent with ``ComponentManager.notify(host, &"dodged")``. Status
  triggers with that event react to it, and components hear it in ``_on_event()``.
- **An input action** is added in the Input Map and to the
  :ref:`PlayerBrain<class_PlayerBrain>`'s Extra Actions. Components then read it from the brain,
  and AI presses it with ``press()``.
