.. _doc_extending:

Extending the system
====================

Most new gameplay needs no new code: a status, an ability or an item made of the existing parts in the Inspector. This page is for when it does. It starts with how to decide where an idea belongs, then shows one complete script of each kind you can add. Every script here is a real file in the project, covered by ``tests/test_extending.gd``, so you can use it as it is or copy it as a starting point.

.. _doc_ability_status_or_component:

Ability, status, effect or component?
-------------------------------------

New gameplay usually fits one of these places:

- An **ability** is one action that happens once per press, with a cooldown, a cost and a
  cast time if you want them.
- A **status** changes numbers and reacts to events, for a while or as long as something holds
  it.
- An **effect** is one instant change to a target, such as damage or a knockback. Abilities,
  statuses, weapons and zones all run effects, so a new one works in all four.
- An **amount** is a number worked out when an effect runs, such as "2 per point of strength".
  A new one fits every effect that has a number.
- A **component** is ongoing behaviour with its own memory, running every frame. On an item,
  it's an **item component**.
- A **movement mode** or **layered move** is a new way for the character to move, under its
  :ref:`CharacterMotor<class_CharacterMotor>`.

To place a new idea, ask in this order:

1. Does it happen once per press, then cool down? Make it an **ability**.
2. Does it change a number, or react to hits or deaths, for a while or while equipped? Make it a
   **status**, which an ability, item or zone can apply.
3. Is the missing piece one instant change, such as "spawn a puddle"? Write an **effect** and
   use it in an ability or status. If only the number is missing, such as "more damage the
   further away the target is", write an **amount** instead.
4. Does it change how the character moves, such as climbing, gliding or wall jumps? Make it a
   **movement mode** or **layered move**.
5. Does it need memory between frames or presses, a held button, or a change to how the
   character acts? Make it a **component**.

.. list-table::
   :header-rows: 1
   :widths: 20 40 40

   * -
     - Good at
     - Limits
   * - Ability
     - One-off actions such as a heal, a fireball, a dash or applying a buff, with a cooldown,
       charges, costs from pools, conditions, a cast time that can be interrupted, and status
       tags that block it. Built in the Inspector with no code when the effects exist. Granted
       or removed during play by changing ``slots``, or by an item; AI calls ``use()``.
     - Starts only on a fresh press: nothing while held or on release, so no charge-up by
       holding and no channelling. Effects are instant, so anything lasting goes through a
       status. It remembers nothing between uses but its cooldown and charges.
   * - Status
     - Stat changes, reactions to events (shields, thorns, crits, life steal, heal on kill),
       immunities and passives. Built in the Inspector. Timed, stacked, or held by items and
       zones.
     - Can't read buttons or run every frame, except ticks at ``tick_interval``. Its triggers
       have no cooldown of their own.
   * - Effect
     - Instant changes that every source can use. A few lines of code.
     - Remembers nothing: the resource is shared, so per-use values go in the context.
   * - Amount
     - A number that depends on who is involved. A few lines of code, and it then works in
       damage, healing and pool effects alike.
     - Remembers nothing either. It only returns a number; it can't change anything.
   * - Component
     - Anything that runs every frame, remembers state, reads held buttons, owns stats that
       statuses can change, or needs other components.
     - Needs GDScript and the start and stop lifecycle. Added to each character's scene, so
       designers can't mix and match them as freely as resources. No built-in cooldowns or
       costs.
   * - Mode or move
     - New ways to move that work alongside the others: a press used by one feature never
       triggers another, and new ones need no changes to the existing ones.
     - Needs GDScript. Only changes the character's velocity: anything else, such as an
       animation, listens to the motor's signals.

Some examples:

.. list-table::
   :header-rows: 1
   :widths: 30 20 50

   * - Idea
     - Where
     - Why
   * - Double jump
     - Setting
     - :ref:`AirMode<class_AirMode>` already does it: ``air_jumps`` is 1. See
       :ref:`doc_movement_walk_and_air`.
   * - Learning to double jump, or boots that grant it
     - Status
     - Adds 1 to the ``air_jumps`` stat that :ref:`AirMode<class_AirMode>` owns.
   * - Dash that controls the character for its whole length
     - Layered move
     - :ref:`DashMove<class_DashMove>`. See :ref:`doc_movement_dash`.
   * - Quick shove forward
     - Ability
     - Once per press: a :ref:`KnockbackEffect<class_KnockbackEffect>` on the user, then a
       cooldown.
   * - Being rooted stops dashing and climbing
     - Status
     - Put ``movement`` in the status's Blocks. See
       :ref:`doc_movement_statuses_events_cooldowns`.
   * - A stun
     - Status
     - A status with ``everything`` in its Blocks and nothing else: the
       :ref:`Brain<class_Brain>` answers to that name. ``starter_pack/statuses/stunned.tres``.
   * - A fireball that costs mana and takes a moment to cast
     - Ability
     - Costs, Cast Time and a :ref:`LaunchProjectileEffect<class_LaunchProjectileEffect>`.
       ``starter_pack/abilities/fireball.tres``.
   * - Damage that grows with strength or level
     - Setting
     - A :ref:`StatAmount<class_StatAmount>` in the effect's Scaling, and the stat in the
       :ref:`ComponentManager<class_ComponentManager>`'s Stats. See :ref:`doc_amounts`.
   * - Critical hits
     - Status
     - A passive with a ``dealing_damage`` trigger and a
       :ref:`ChanceCondition<class_ChanceCondition>`. ``starter_pack/statuses/lucky_strikes.tres``.
   * - Life steal, heal on kill
     - Status
     - Triggers on ``dealt_damage`` and ``killed``. ``starter_pack/statuses/vampiric.tres`` and
       ``bloodlust.tres``.
   * - A shield that recharges out of combat
     - Setting
     - A :ref:`Pool<class_Pool>` with Absorbs Damage, Regen and Regen Delay.
   * - Mana, stamina, rage
     - Setting
     - A :ref:`Pool<class_Pool>` for each.
   * - A ring with +25 health; loot with random numbers
     - Item
     - :ref:`Grants<class_Grants>`. See
       :ref:`doc_stats_and_abilities_from_equipment`.
   * - A rocket launcher, a bow
     - Item
     - A :ref:`LaunchProjectileEffect<class_LaunchProjectileEffect>` in the
       :ref:`Trigger<class_Trigger>`'s User Effects, and a :ref:`Projectile<class_Projectile>`
       scene. See :ref:`doc_projectiles`.
   * - Experience for kills, a quest that counts deaths
     - Level script
     - One :ref:`WorldEvents<class_WorldEvents>` listener. See :ref:`doc_events`.
   * - Shockwave on landing
     - Status
     - A trigger on ``walk_mode_entered``, the event the motor sends on landing.
   * - Wall slide, swimming, climbing
     - Movement mode
     - A different way of moving that takes over from walking or falling. See
       :ref:`doc_extending_movement`.
   * - Sprint for a few seconds
     - Ability
     - Once per press: applies a speed status (``starter_pack/abilities/sprint.tres`` applies
       Haste).
   * - Sprint while a button is held, with stamina
     - Component
     - Reads a held button every frame and remembers stamina. See :ref:`doc_extending_component`.
   * - A water spell that leaves a puddle
     - Ability + effect
     - Once per press, and the puddle is one instant change: :ref:`SpawnSceneEffect<class_SpawnSceneEffect>`.
   * - Glide while holding jump
     - Layered move
     - Changes the fall on top of the air mode while a button is held. See
       :ref:`doc_extending_movement`.
   * - A heavy swing that winds up
     - Data
     - **Wind Up** on the weapon's :ref:`Trigger<class_Trigger>`, and **Active** on its
       :ref:`MeleeSweep<class_MeleeSweep>` for a swing that follows the blade. See
       :ref:`doc_timing_and_animation`.
   * - A bow that is drawn, a charged shot
     - Data
     - **Charge Time** on the weapon's Trigger, and a :ref:`ChargeAmount<class_ChargeAmount>`
       wherever the charge should count. See :ref:`doc_charging`.
   * - An animation for an attack, a cast or a death
     - Data
     - A row in the character's :ref:`Animator<class_Animator>`. See :ref:`doc_animator`.

When new behaviour needs code, prefer a new :ref:`Effect<class_Effect>` over a new component where you can: one effect works in abilities, statuses, weapons and zones at once. Most of the grey area comes from the ability limits above. A spell that charges up while its button is held, or channels until it's let go, can't be an ability, so it would be a component of its own that reads the held button.

.. _doc_extending_checklist:

Before you write a script
-------------------------

- **Give it a** ``class_name``. Components then appear in the Add Node dialog, and effects,
  conditions and targeting in the Inspector's resource lists.
- **Do setup in** ``_start()``, **not** ``_ready()``. ``_start()`` runs once everything in
  ``_requires()`` is present, and never in the editor. Undo in ``_stop()`` whatever ``listen()``
  and ``on()`` don't undo for you: stat modifiers, groups, spawned nodes.
- **Hear events with** ``on()``. ``on(&"took_damage", _on_took_damage)`` in ``_start()`` calls
  your method for that event until the component stops. :ref:`doc_events` lists the events.
- **Look things up when you need them.** ``find(Type)`` for a component beside yours,
  ``Health.find_on(node)`` for one on another node. Both are cheap, so don't keep the
  result in a variable: components can come and go during play. The built-in components a
  game looks up have ``find_on()``; for your own, ``Component.of(node, Type) as Type`` does
  the same, and :ref:`Component.of<class_Component_method_of>` shows the two lines that give
  your type its own.
- **Read numbers with** ``stat()`` **at the moment you use them.** Numbers statuses should be
  able to change go in your component's ``_stats()``; call ``update_stats()`` when you change
  one yourself.
- **Resources are shared.** One effect, condition, status or item resource is used by every
  character at once, so it must not remember anything between uses. Per-use values go in the
  :ref:`EffectContext<class_EffectContext>`, per-character state in a component, and an item's
  own state, such as rounds loaded, in ``item.state``.
- **Cope with what isn't there.** An effect can hit a wall and a condition can check a crate,
  so check for null after every ``find_on()``.
- **Give a name field its usual name.** An exported ``stat``, ``pool``, ``event``, ``tag``,
  ``tags``, ``blocks`` or ``blocked_by`` in a script that starts with ``@tool`` becomes a
  :ref:`list to pick from <doc_name_lists>` in the Inspector, with no code.
- **Add** ``@tool`` **to components for editor warnings.** The base class turns processing off
  in the editor and never calls ``_start()`` there, but your own ``_ready()`` would still run,
  which is one more reason to set up in ``_start()``. The
  :ref:`editor warnings <doc_editor_warnings_for_names>` also learn the stat names in your
  ``_stats()`` and the events you ``notify()``.

The :ref:`pitfalls <doc_pitfalls>` list the mistakes that are easiest to make.

.. _doc_extending_component:

A component
-----------

:ref:`Sprint<class_Sprint>` lets a character run faster while a button is held, for as long as a :ref:`Pool<class_Pool>` named ``stamina`` has something left. The stamina itself is an ordinary pool beside it, with a Regen and a Regen Delay; the component only spends from it, which is all a component of your own has to do to use a resource.

.. source-file:: ../../character_system/starter_pack/scripts/sprint.gd

Each part does one job:

- ``_requires()`` returns ``[Brain, CharacterMotor]``, so the component waits, with a warning,
  until both are beside it. Sprinting means nothing without movement.
- It owns no stats: the maximum and the refill rate are the pool's ``max_stamina`` and
  ``stamina_regen``, which a status can change with a
  :ref:`StatModifier<class_StatModifier>`. A component that does own a number returns it
  from ``_stats()``.
- ``_process()`` only runs while the component runs, so it can use the Brain without a null
  check. It reads the button with ``is_action_pressed()``, which stays true while it's held.
- The speed boost is a stat modifier added to the manager, so it combines with every other
  speed change, such as Wet slowing the character down. ``_stop()`` takes it off, so removing
  the component mid-sprint leaves nothing behind.
- ``_warnings()`` tells the editor when there is no pool with that name beside it.

To use it, add it to a character beside the CharacterMotor, with a Pool named ``stamina``, add a ``sprint`` action to the Input Map, and add ``sprint`` to the :ref:`PlayerBrain<class_PlayerBrain>`'s Extra Actions.

.. _doc_extending_movement:

A movement mode or move
-----------------------

New ways to move go under the character's :ref:`CharacterMotor<class_CharacterMotor>` (see :ref:`doc_movement`). Pick the kind by asking whether it replaces how the character moves or adds to it:

- A **movement mode** replaces it: swimming, climbing, sliding down a wall. Extend
  :ref:`MovementMode<class_MovementMode>`.
- A **layered move** adds to whatever mode is in charge, for a while: a dash, a glide, a
  grapple pull. Extend :ref:`LayeredMove<class_LayeredMove>`.

:ref:`WallSlideMode<class_WallSlideMode>` slides slowly down a wall while the character falls against it, and jumps off it:

.. source-file:: ../../character_system/starter_pack/scripts/wall_slide_mode.gd

- ``_can_enter()`` lets it take over by itself once the character falls against a wall. The
  motor asks every mode that isn't in charge, so WalkMode and AirMode don't need to know this
  one exists.
- ``_physics_update()`` sets ``body.velocity`` like the CharacterBody3D template does, using the
  ``move_speed`` and ``jump_velocity`` stats, so statuses that change them work here too. It
  never calls ``move_and_slide()``: the motor does.
- ``motor.consume_action()`` uses up the jump press, so nothing else jumps on it.
- ``_get_next_mode()`` hands back to walking or falling once the wall is gone.

:ref:`GlideMove<class_GlideMove>` slows the fall while jump is held:

.. source-file:: ../../character_system/starter_pack/scripts/glide_move.gd

- ``_can_start()`` is asked every frame while it's idle. It reads the held button with
  ``is_action_pressed()``, which doesn't use anything up, so AirMode still gets the press for its
  double jump.
- It runs after the mode each frame, so it only has to cap the fall speed AirMode just set.
- It sets ``active`` to false to end itself.

Modes and moves are plain nodes, not components:

- **Add them as children of the motor.** Anywhere else, they show a warning.
- **Use** ``_enter()`` **and** ``_exit()`` **for setup and cleanup**, not ``_ready()``: they run
  when a mode takes over or hands over, or when a move starts or ends.
- **Own numbers statuses should change** in ``_stats()``, as components do, and read them with
  ``stat()``. Call ``update_stats()`` when you change one yourself.
- **Read the brain through** ``motor.brain``, and the body through ``body``.

To use either example, add it as a child of a character's CharacterMotor. Both are covered by ``tests/test_extending.gd``.

.. _doc_extending_item_component:

An item component
-----------------

Item components extend :ref:`ItemComponent<class_ItemComponent>`, which adds ``wielder`` (the character holding the item), ``item`` (this copy of it) and ``brain`` (the wielder's brain). There are two common kinds.

**One that decides what a shot reaches** extends :ref:`WeaponDelivery<class_WeaponDelivery>` and writes one method, ``_fire()``, which runs each time the item's :ref:`Trigger<class_Trigger>` fires. :ref:`MeleeSweep<class_MeleeSweep>` hits everything inside a shape in front of the item:

.. source-file:: ../../character_system/character/items/melee_sweep.gd

The base class brings the rest, so a new one has only its own settings and its ``_fire()``:

- the Effects and Collision Mask fields, and the name warnings for the effects,
- the wait for a Trigger and the connection to its ``fired`` signal,
- ``_wielder_rids``, the wielder's body and hurtboxes, so shots can pass through them,
- ``context_for(collider, position, normal)``, which builds each hit's context: it turns a
  hurtbox into its character, applies its multiplier, and records the item as ``origin``.

This one hits whatever a :ref:`Targeting<class_Targeting>` finds around the wielder, which makes a shock baton out of the same targeting an ability uses:

.. code-block:: gdscript

    class_name Pulse
    extends WeaponDelivery

    @export var targeting: Targeting

    func _fire() -> void:
    	for target in targeting.find(context_for(wielder)):
    		Effect.apply_all(effects, context_for(target))

An item component that acts on use without hitting anything, such as a flashlight, extends :ref:`ItemComponent<class_ItemComponent>` and listens to the Trigger itself: return ``[Trigger]`` from ``_requires()`` and call ``listen((find(Trigger) as Trigger).fired, _on_fired)`` in ``_start()``.

To make a sword, build an item scene with a :ref:`ComponentManager<class_ComponentManager>`, a Trigger and a MeleeSweep with a BoxShape3D about a metre across and a :ref:`DamageEffect<class_DamageEffect>` in its effects. A projectile weapon needs no delivery component: a :ref:`LaunchProjectileEffect<class_LaunchProjectileEffect>` in the Trigger's ``user_effects`` launches a :ref:`Projectile<class_Projectile>`, which applies the effects to what it touches; see :ref:`doc_projectiles`.

**One that changes the wielder while equipped** finds what it needs in ``_start()`` and undoes everything in ``_stop()``, which runs on unequip. :ref:`Scope<class_Scope>` zooms the wielder's camera and slows it down while the aim button is held:

.. source-file:: ../../character_system/starter_pack/scripts/scope.gd

Whatever an item changes on its wielder must be undone in ``_stop()``. A stat modifier left on the wielder's manager would slow the character for the rest of the game.

An item component hears its wielder's events by passing the wielder to ``on()``, and that is undone on unequip like everything else:

.. code-block:: gdscript

    class_name KillCounter
    extends ItemComponent
    ## Counts this copy's kills, e.g. for a weapon that names itself after ten.

    func _start() -> void:
    	on(&"killed", _on_wielder_killed, wielder)

    func _on_wielder_killed(_ctx: EffectContext) -> void:
    	item.state[&"kills"] = item.state.get(&"kills", 0) + 1  # Kept between equips.

.. _doc_extending_effect:

An effect
---------

An effect extends :ref:`Effect<class_Effect>` and overrides ``_execute(ctx)``. :ref:`SpawnSceneEffect<class_SpawnSceneEffect>` spawns a scene, such as a puddle or an explosion, where the target is:

.. source-file:: ../../character_system/character/effects/spawn_scene_effect.gd

- Its numbers are ``@export`` variables, so each use is set up in the Inspector.
- ``ctx.target`` is whoever it happens to, and may be anything: a character, a crate or null.
  It checks before using it.
- It adds the scene with ``call_deferred()``, because effects can run inside physics callbacks
  such as a zone's ``body_entered``, where new areas can't be added yet.
- It stores nothing on itself between uses.

Conditions work on every effect without any code: put one in its ``conditions`` and the effect only runs when it passes.

**An effect with a number** extends :ref:`AmountEffect<class_AmountEffect>` instead. That gives it the Amount and Scaling fields of :ref:`DamageEffect<class_DamageEffect>` and :ref:`HealEffect<class_HealEffect>`, and ``total(ctx)``: the plain number plus every :ref:`Amount<class_Amount>` in the list, times ``ctx.magnitude``, so status stacks and headshots strengthen it. This one moves mana from the target to whoever caused it, and takes more for each point of the user's spell power once a :ref:`StatAmount<class_StatAmount>` is in its Scaling:

.. code-block:: gdscript

    class_name SiphonEffect
    extends AmountEffect

    func _execute(ctx: EffectContext) -> void:
    	var theirs := Pool.named(ctx.target, &"mana")
    	var mine := Pool.named(ctx.source, &"mana")
    	if theirs and mine:  # Either may have no mana, or be a wall.
    		var taken: float = minf(theirs.current, total(ctx))
    		theirs.change(-taken)
    		mine.change(taken)

.. _doc_extending_amount:

An amount
---------

An amount extends :ref:`Amount<class_Amount>` and overrides ``value(ctx)``. :ref:`StatAmount<class_StatAmount>` reads a stat from one side of the effect and multiplies it:

.. source-file:: ../../character_system/core/amounts/stat_amount.gd

- ``ctx.source`` and ``ctx.target`` may be null or have no components.
  ``ComponentManager.stat_of()`` returns 0 for those, so the amount adds nothing.
- It keeps nothing between uses, like an effect.
- It's read when the effect runs, so a stat that changed a moment ago already counts.

The :ref:`Amount<class_Amount>` reference has a short one of your own to copy, which grows with distance.

To make a water spell, give an ability two effects: an :ref:`ApplyStatusEffect<class_ApplyStatusEffect>` with Wet, and a SpawnSceneEffect with ``starter_pack/zones/water_pool.tscn`` and a lifetime of 10 seconds.

.. _doc_extending_condition:

A condition
-----------

A condition extends :ref:`Condition<class_Condition>`. Most override ``_test(node)``, which checks one side; ``subject`` picks which side and ``negate`` flips the answer, with no code of your own. The :ref:`Condition<class_Condition>` reference shows one. A condition that compares both sides overrides ``check(ctx)`` instead, like :ref:`IsHostileCondition<class_IsHostileCondition>`:

.. source-file:: ../../character_system/character/conditions/is_hostile_condition.gd

Put it in the ``conditions`` of a weapon's DamageEffect to turn friendly fire off: allies are still hit, but take no damage.

.. _doc_extending_targeting:

Ability targeting
-----------------

An ability's ``targeting`` decides who its effects reach. Left empty, it's the user. :ref:`RadiusTargeting<class_RadiusTargeting>` picks everything within a radius:

.. source-file:: ../../character_system/character/abilities/radius_targeting.gd

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

.. source-file:: ../../character_system/starter_pack/scripts/attack_nearest.gd

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

.. source-file:: ../../character_system/starter_pack/scripts/character_hud.gd

.. _doc_extending_names:

New stats, damage types, events and actions
-------------------------------------------

None of these need a change to the system:

- **A stat** is any name a component returns from ``_stats()``, such as ``max_stamina``.
  Statuses change it with a :ref:`StatModifier<class_StatModifier>` of the same name, and the
  component reads it with ``stat()``.
- **A damage type** is any name in :ref:`DamageEffect<class_DamageEffect>`'s ``type``, such as
  ``lightning``. Resistance to it is the ``resist_lightning`` stat: add it to
  :ref:`Health<class_Health>`'s resistances, or give it to a status as a modifier. Extra
  damage dealt with it is the ``bonus_lightning`` stat.
- **A stat of your game's own**, such as ``strength``, doesn't even need a component of
  yours: list it in the :ref:`ComponentManager<class_ComponentManager>`'s Stats in the Inspector.
- **A pool** is a :ref:`Pool<class_Pool>` component with a name of your choosing, such as
  ``energy``. Abilities spend it through their costs, and its two stats are ``max_energy``
  and ``energy_regen``.
- **An event** is any name sent with ``ComponentManager.notify(host, &"dodged")``. Status
  triggers with that event react to it, and components hear it with
  ``on(&"dodged", _on_dodged)``.
- **A hit tag** is any name in a :ref:`Hurtbox<class_Hurtbox>`'s or a
  :ref:`DamageEffect<class_DamageEffect>`'s tags, such as ``head`` or ``melee``. A
  :ref:`HitCondition<class_HitCondition>` tests it.
- **An input action** is added in the Input Map and to the
  :ref:`PlayerBrain<class_PlayerBrain>`'s Extra Actions. Components then read it from the brain,
  and AI presses it with ``press()``.
