.. _doc_effects_statuses_and_passives:

Effects, statuses and passives
==============================

An :ref:`Effect<class_Effect>` is one instant change to a target; a status is a container of effects and stat modifiers that lives on a character for a while. A passive is a status with no duration. A :ref:`Condition<class_Condition>` decides whether an effect runs, or whether a status can be applied. Together these cover damage over time, buffs, auras, on-hit procs, shields, immunities, conditional bonuses and equipment bonuses.

.. _doc_effects:

Effects
-------

.. source-file:: ../../character_system/core/effect_context.gd

.. source-file:: ../../character_system/resources/effects/_base/effect.gd

To make a new effect, extend :ref:`Effect<class_Effect>`, add ``@export`` fields for its numbers, and write ``_execute()``. Conditions then work on it automatically. :ref:`doc_extending_effect` walks through one.

.. source-file:: ../../character_system/resources/effects/damage_effect.gd

Resistance is clamped to 0 to 1 and the final amount is never negative, so stacking resistances can block damage but never turn it into healing.

.. source-file:: ../../character_system/resources/effects/heal_effect.gd

.. source-file:: ../../character_system/resources/effects/apply_status_effect.gd

.. source-file:: ../../character_system/resources/effects/remove_status_effect.gd

.. source-file:: ../../character_system/resources/effects/modify_amount_effect.gd

:ref:`ModifyAmountEffect<class_ModifyAmountEffect>` is what makes the damage pipeline work. :ref:`DamageEffect<class_DamageEffect>` announces the hit before it lands, a status trigger reacts with this effect, and the effect edits the pending amount through ``ctx.cause``.

.. source-file:: ../../character_system/resources/effects/knockback_effect.gd

:ref:`KnockbackEffect<class_KnockbackEffect>` shows the rule that every effect handles a target without the component it needs: a character is shoved through ``CharacterMotor.push()``, a physics prop gets an impulse, and a wall is left alone.

.. source-file:: ../../character_system/resources/effects/spawn_scene_effect.gd

:ref:`SpawnSceneEffect<class_SpawnSceneEffect>` spawns a scene where the target is, such as a puddle that is itself an :ref:`EffectZone<class_EffectZone>`, so a status or an ability can leave ground that applies further statuses.

.. _doc_conditions:

Conditions
----------

.. source-file:: ../../character_system/resources/conditions/_base/condition.gd

.. source-file:: ../../character_system/resources/conditions/has_tag_condition.gd

.. source-file:: ../../character_system/resources/conditions/health_below_condition.gd

.. source-file:: ../../character_system/resources/conditions/stat_condition.gd

``_test(node) != negate`` is a compact way to flip the result: when ``negate`` is true, true becomes false and false becomes true. ``Condition.all_pass()`` is shared by effects and by status apply conditions, described under Status data.

.. source-file:: ../../character_system/resources/conditions/is_hostile_condition.gd

:ref:`IsHostileCondition<class_IsHostileCondition>` compares both sides, so it overrides ``check(ctx)`` instead of ``_test(node)``. On a weapon's damage effect, it turns friendly fire off. :ref:`doc_extending_condition` shows how to write your own.

.. _doc_status_data:

Status data
-----------

.. source-file:: ../../character_system/resources/statuses/status_trigger.gd

.. source-file:: ../../character_system/resources/statuses/status_data.gd

``@export_group`` sorts the fields into collapsible sections in the inspector, so designers see Display, Rules and Effects separately.

.. list-table::
   :header-rows: 1

   * - Field group
     - Gives you
     - Baldur's Gate 3 style example
   * - ``display_name``, ``icon``, ``description``
     - What the status bar and tooltip show
     - A flame icon with "Takes fire damage each second"
   * - ``immune_to``
     - Status tags it keeps out while active
     - Wet keeps out fire; an Undead trait keeps out poison
   * - ``apply_conditions``
     - Rules for whether it can be applied at all
     - A burn that can't be applied to a target with ``resist_fire`` of 1 or more
   * - ``modifiers``
     - Stat changes while active
     - Haste: movement speed multiplied by 1.5
   * - ``on_apply``, ``on_tick``, ``on_remove``
     - Instant and periodic effects
     - Burning: fire damage every second
   * - ``triggers``
     - Reactions to events
     - Thorns: damage the attacker when hit
   * - ``tags``, ``removes_tags``
     - Interactions between statuses
     - Wet puts out Burning when it is added
   * - ``stacking``, ``max_stacks``
     - Reapply rules
     - Poisoned stacks to 3, each stack adding tick damage

.. _doc_events:

Events
------

An event reaches every running component on a host through ``_on_event()``. Statuses passes it on to triggers; your own components can react too. The four damage events are built in, :ref:`Health<class_Health>` sends ``died``, the manager sends ``started``, and :ref:`Inventory<class_Inventory>` sends ``inventory_changed``. Status triggers only react to events that carry a context, so ``started`` and ``inventory_changed`` reach components but never triggers, and ``died`` reaches triggers only when something dealt the killing blow. Any system can add more with one line, such as ``ComponentManager.notify(host, &"jumped")``. ``notify()`` gives the event a context with the host as the target, so triggers react to it; pass your own :ref:`EffectContext<class_EffectContext>` as a third argument to say who caused it.

.. list-table::
   :header-rows: 1

   * - Event
     - Sent to
     - When
     - Typical use
   * - ``dealing_damage``
     - Attacker
     - Before damage lands; ``amount`` can be changed
     - Crits, damage buffs, "+50% damage to wet targets"
   * - ``taking_damage``
     - Victim
     - Before damage lands; ``amount`` can be changed
     - Shields, flat armor
   * - ``dealt_damage``
     - Attacker
     - After damage lands
     - On-hit procs, lifesteal
   * - ``took_damage``
     - Victim
     - After damage lands
     - Thorns, "enrage when hit"
   * - ``died``
     - The character that died
     - Its health reaches zero
     - Ending timed statuses, on-death effects
   * - ``started``
     - Every component on the host; no context
     - All its components have had the chance to start
     - :ref:`Health<class_Health>` settling at full health
   * - ``inventory_changed``
     - Every component on the host; no context
     - Something was added to or removed from the Inventory
     - Equipment unequipping a dropped item, WeaponSwitch drawing a weapon

.. _doc_example_statuses:

Example statuses
----------------

These ship in ``character_system/examples/`` as ``.tres`` files with no code. Duplicate one (right-click > Duplicate) and change the copy.

.. list-table::
   :header-rows: 1
   :widths: 20 25 55

   * - Status
     - File
     - Fields set
   * - Burning
     - ``statuses/burning.tres``
     - ``tags`` = fire. ``duration`` = 4. ``tick_interval`` = 1. ``on_tick`` = 4 fire damage.
       The fire patch zone and the flare gun apply it.
   * - Poisoned
     - ``statuses/poisoned.tres``
     - ``tags`` = poison. ``duration`` = 6. ``stacking`` = STACK, ``max_stacks`` = 3.
       ``tick_interval`` = 1. ``on_tick`` = 2 poison damage, times the stacks.
   * - Wet (passive)
     - ``statuses/wet.tres``
     - ``tags`` = wet. ``duration`` = 0. ``modifiers`` = ``move_speed`` × 0.6.
       ``immune_to`` = fire. ``removes_tags`` = fire. The water pool gives it while inside.
   * - Regenerating (passive)
     - ``statuses/regenerating.tres``
     - ``tags`` = healing. ``duration`` = 0. ``tick_interval`` = 1. ``on_tick`` = heal 8. The
       healing pad gives it while inside.
   * - Warded (passive)
     - ``statuses/warded.tres``
     - ``tags`` = ward. ``duration`` = 0. ``triggers`` = on ``taking_damage``,
       ``react_to_statuses`` on, modify amount × 0.5, so burn and poison ticks are halved
       too. The ward circle and the ward amulet give it.
   * - Haste
     - ``statuses/haste.tres``
     - ``tags`` = haste. ``duration`` = 8. ``modifiers`` = ``move_speed`` × 1.5. The Sprint
       ability applies it.
   * - Thorns (passive)
     - ``statuses/thorns.tres``
     - ``tags`` = thorns. ``duration`` = 0. ``triggers`` = on ``took_damage``, affect other,
       3 physical damage.
   * - Fireproof (passive)
     - ``statuses/fireproof.tres``
     - ``tags`` = fireproof. ``duration`` = 0. ``immune_to`` = fire. The fireproof cloak gives
       it.
   * - Undead (trait)
     - ``traits/undead.tres``
     - ``tags`` = undead. ``duration`` = 0. ``immune_to`` = poison.
   * - Construct (trait)
     - ``traits/construct.tres``
     - ``tags`` = construct. ``duration`` = 0. ``immune_to`` = fire, poison.

More ideas, built from the same fields. These aren't in ``examples/``:

.. list-table::
   :header-rows: 1
   :widths: 25 75

   * - Idea
     - Fields to set
   * - Stoneskin
     - ``duration`` = 30. ``triggers`` = on ``taking_damage``, ``react_to_statuses`` on, a
       :ref:`ModifyAmountEffect<class_ModifyAmountEffect>` with ``add`` -3.
   * - Executioner (passive)
     - ``duration`` = 0. ``triggers`` = on ``dealing_damage``, affect other, a
       ModifyAmountEffect with ``mul`` 1.5 and a
       :ref:`HealthBelowCondition<class_HealthBelowCondition>` (fraction 0.3). Affect other
       makes the condition check the victim, not the attacker.
   * - Flaming blade (passive)
     - ``duration`` = 0. ``triggers`` = on ``dealt_damage``, affect other, an
       :ref:`ApplyStatusEffect<class_ApplyStatusEffect>` with Burning.
   * - Hunter's mark
     - ``duration`` = 10. ``modifiers`` = ``resist_physical`` -0.2. ``apply_conditions`` =
       :ref:`HasTagCondition<class_HasTagCondition>` (subject SOURCE, tag ``ranger``), so only
       rangers can apply it.

.. _doc_restricting_who_gets_a_status:

Restricting who gets a status
-----------------------------

A status can be refused in two ways, both checked by ``add()`` before anything else happens. A refused status changes nothing: no effects run, no stacks are added, and whatever tried to apply it (a weapon, an ability, a zone) simply does nothing.

**``immune_to`` is the usual way, and it lives on the protector.** While a status is active, statuses with any of its ``immune_to`` tags can't be added. Traits are innate passives (see :ref:`Passives <doc_passives>`), so an Undead trait with ``immune_to`` = ``poison`` keeps out every poison status, and a new poison status needs nothing but its tag.

**``apply_conditions`` is for rules that aren't about other statuses.** It uses the same :ref:`Condition<class_Condition>` resources as effects. The target is the character receiving the status, and the source is whoever applies it.

.. list-table::
   :header-rows: 1

   * - Goal
     - Set up
   * - Undead can't be poisoned
     - Undead trait: ``immune_to`` = ``poison``
   * - Constructs can't burn or be poisoned
     - Construct trait: ``immune_to`` = ``fire``, ``poison``
   * - Wet characters can't burn, and water puts fire out
     - Wet: ``immune_to`` = ``fire``, ``removes_tags`` = ``fire``
   * - An item makes its wearer fireproof
     - A Fireproof passive with ``immune_to`` = ``fire``, given by the item's :ref:`GrantStatuses<class_GrantStatuses>`
   * - Targets with full fire resistance can't burn
     - Burning: ``apply_conditions`` = StatCondition: stat ``resist_fire``, value 1, negate on
   * - Only rangers can apply Hunter's mark
     - Hunter's mark: ``apply_conditions`` = HasTagCondition: subject SOURCE, tag ``ranger``
   * - Execution marks only land on wounded targets
     - Execution mark: ``apply_conditions`` = HealthBelowCondition: fraction 0.25

When a status is refused, ``add()`` returns false and :ref:`Statuses<class_Statuses>` emits ``refused``, so the UI can show "Immune". ``StatusData.can_apply()`` runs the same immunity and condition checks without applying anything, for example to grey out an ability before it is used. Because immunities live on the protector, a status's own resource doesn't show who is immune to it: search your statuses for its tags.

.. _doc_passives:

Passives
--------

A passive is a status with ``duration`` 0. There is no separate passive system: passives go through the same ``add()`` as any status, so they can have modifiers, triggers, tags, ``immune_to`` and apply conditions. What differs is how they start and end.

.. list-table::
   :header-rows: 1

   * - Source
     - Added when
     - Ends when
   * - Character trait, in ``Statuses.innate``
     - The character's :ref:`Statuses<class_Statuses>` starts
     - Never, unless code removes it
   * - Item, through :ref:`GrantStatuses<class_GrantStatuses>`
     - The item is equipped
     - The item is unequipped
   * - Zone, through ``status_while_inside``
     - A body enters
     - It leaves, or the zone is removed
   * - Effect or ability, through :ref:`ApplyStatusEffect<class_ApplyStatusEffect>`
     - The effect runs
     - A cleanse removes it with :ref:`RemoveStatusEffect<class_RemoveStatusEffect>`

-  **Holds.** Each source that adds a passive is one hold, and ``drop_hold()`` drops one. The passive ends when no holds remain, so two rings of haste keep Haste until both come off.
-  **Stacking.** With ``REFRESH``, a passive has one stack however many sources hold it. With ``STACK``, each hold adds a stack up to ``max_stacks``, so two rings of might give double the bonus.
-  **Refusals.** A passive is checked once, when it is added. Innate passives are checked when the character starts. An item passive that is refused is not retried until the item is equipped again, and :ref:`GrantStatuses<class_GrantStatuses>` only drops holds on the passives it was given.
-  **Death.** Passives survive death, because only timed statuses end when a character dies, so a revived character keeps its traits and item passives.

**Traits are passives with tags.** Characters have no tag list of their own. A trait such as undead, construct or fire immune is an innate passive whose only job may be to carry a tag. That is how characters get immunities:

.. list-table::
   :header-rows: 1

   * - Trait
     - Set up
     - Effect
   * - Fire immunity
     - ``tags`` = ``fire_immune``, ``immune_to`` = ``fire``
     - No fire status can be added to this character
   * - Undead
     - ``tags`` = ``undead``, ``immune_to`` = ``poison``
     - Poison never lands on undead characters

A trait gained during play, such as a curse that turns a character undead, does not remove statuses it already has: ``immune_to`` only keeps out new ones. Give the trait ``removes_tags`` (Undead with ``removes_tags`` = ``poison``) if it should.

.. _doc_statuses_component:

Statuses component
------------------

.. source-file:: ../../character_system/characters/components/statuses.gd

The rules this component enforces:

-  **Refusals come first.** ``add()`` checks immunities (``immune_to`` on statuses the character already has) and ``apply_conditions`` before anything else. A refused status changes nothing: ``add()`` returns false and ``refused`` is emitted.
-  **One instance per status.** Reapplying refreshes the duration. With ``STACK`` it also adds a stack up to ``max_stacks``, and modifiers and effect magnitude scale with stacks.
-  **Timed statuses are removed; permanent ones lose a hold.** A status with duration 0 counts its holds: each item, zone or innate entry that adds it is one hold, and ``drop_hold()`` drops one. Two rings granting Haste keep it until both come off. Cleanses use ``remove()``, which ends it outright.
-  **Statuses don't set off reactions.** Anything a status does is marked ``from_status``, and triggers ignore it unless ``react_to_statuses`` is on. This one rule stops feedback loops, such as two Thorns holders bouncing damage forever. Shields turn it on so they also block burn ticks.
-  **Credit is kept.** Damage from a status tick carries the original applier as ``source``, so kill credit and the applier's ``dealing_damage`` triggers still work.
-  **Death ends timed statuses only.** :ref:`Statuses<class_Statuses>` hears the ``died`` event and removes timed statuses. Burning stops on a corpse, but racial and equipment passives stay, so a revived character keeps them.
-  **Removing the component removes its statuses.** ``_stop()`` takes every status off, so no stat modifier is left behind on the manager.
-  **Passives cost nothing per frame.** ``_process()`` only runs while a status has a ``duration`` or a ``tick_interval``, so a crowd whose only statuses are traits and item passives adds no per-frame work.
