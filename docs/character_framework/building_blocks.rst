.. _doc_framework_building_blocks:

More effects, conditions and amounts
====================================

The core has the effects, conditions and amounts that need nothing but the core: damage, healing, statuses, tags and stats. The character framework adds the ones that need more, such as a motor to push, a faction to compare, a pool to read or a scene to spawn. They go in the same lists and follow the same rules, described in :ref:`doc_effects_statuses_and_passives`.

.. _doc_more_amounts:

Amounts
-------

.. source-file:: ../../character_system/character/amounts/pool_amount.gd

.. source-file:: ../../character_system/character/amounts/hit_amount.gd

.. source-file:: ../../character_system/character/amounts/random_amount.gd

:ref:`ChargeAmount<class_ChargeAmount>`, for weapons that are charged by holding the button, is shown with them in :ref:`doc_charging`.

.. list-table::
   :header-rows: 1

   * - Want
     - Amount plus scaling
   * - Poison that takes 2% of maximum health per tick
     - 0 + :ref:`PoolAmount<class_PoolAmount>` (of TARGET, MAXIMUM, 0.02)
   * - A potion that heals 30% of missing health
     - 0 + PoolAmount (of TARGET, MISSING, 0.3)
   * - Life steal of a quarter of the damage dealt
     - A heal of 0 + :ref:`HitAmount<class_HitAmount>` (0.25), in a ``dealt_damage`` trigger
   * - 8 to 12 damage
     - 8 + :ref:`RandomAmount<class_RandomAmount>` (0 to 4)
   * - An arrow that hits harder the further the bow is drawn
     - 8 + :ref:`ChargeAmount<class_ChargeAmount>` (22 at full)

.. _doc_more_effects:

Effects
-------

.. source-file:: ../../character_system/character/effects/change_pool_effect.gd

.. source-file:: ../../character_system/character/effects/knockback_effect.gd

A :ref:`KnockbackEffect<class_KnockbackEffect>` is an effect with a number too: its **Amount** is the speed of the push, with the same **Scaling** list. It shows the rule that every effect handles a target without the component it needs: a character is shoved through ``CharacterMotor.push()``, a physics prop gets an impulse, and a wall is left alone.

.. source-file:: ../../character_system/character/effects/spawn_scene_effect.gd

:ref:`SpawnSceneEffect<class_SpawnSceneEffect>` spawns a scene where the target is, such as a puddle that is itself an :ref:`EffectZone<class_EffectZone>`, so a status or an ability can leave ground that applies further statuses. With ``at`` set to ``HIT_POINT`` it spawns where the shot landed, for sparks or blood, and with ``SOURCE`` around whoever caused it.

.. source-file:: ../../character_system/character/effects/launch_projectile_effect.gd

:ref:`LaunchProjectileEffect<class_LaunchProjectileEffect>` turns an ability into a fireball; :ref:`doc_projectiles` covers the projectile itself. Its **Speed Scaling** adds to the projectile's speed the way an effect's scaling adds to its number, so a stat or a charge can make it fly faster.

.. _doc_more_conditions:

Conditions
----------

.. source-file:: ../../character_system/character/conditions/pool_below_condition.gd

.. source-file:: ../../character_system/character/conditions/stat_condition.gd

.. source-file:: ../../character_system/character/conditions/is_hostile_condition.gd

:ref:`IsHostileCondition<class_IsHostileCondition>` compares both sides, so it extends :ref:`Condition<class_Condition>` itself and overrides ``_passes(ctx)``, where the two above extend :ref:`SubjectCondition<class_SubjectCondition>` and override ``_test(node)``. On a weapon's damage effect, it turns friendly fire off. :ref:`doc_extending_condition` shows how to write your own.

.. source-file:: ../../character_system/character/conditions/chance_condition.gd

.. source-file:: ../../character_system/character/conditions/hit_condition.gd

.. source-file:: ../../character_system/character/conditions/any_condition.gd

.. list-table::
   :header-rows: 1

   * - Condition
     - Passes when
     - Typical use
   * - :ref:`PoolBelowCondition<class_PoolBelowCondition>`
     - A pool, health unless you name another, is below a fraction of its maximum
     - Executes, last-stand abilities, a speed boost while badly hurt
   * - :ref:`StatCondition<class_StatCondition>`
     - A stat is at least a value
     - A status that can't be applied to the fully resistant
   * - :ref:`IsHostileCondition<class_IsHostileCondition>`
     - The source is hostile to the target
     - Turning friendly fire off
   * - :ref:`ChanceCondition<class_ChanceCondition>`
     - A roll succeeds; a stat such as ``crit_chance`` can add to the odds
     - Critical hits, a 1 in 5 chance to set alight
   * - :ref:`HitCondition<class_HitCondition>`
     - The hit's damage type is one of those listed, and the hit has every tag listed
     - A ward against fire only, headshot bonuses, reacting to melee hits or to crits
   * - :ref:`AnyCondition<class_AnyCondition>`
     - At least one of the conditions inside it passes
     - "Wet or below half health"
   * - :ref:`ChargeCondition<class_ChargeCondition>`
     - The weapon was charged at least so far (see :ref:`doc_charging`)
     - Bleeding only from a fully drawn bow

A list of conditions needs all of them to pass; put alternatives inside an :ref:`AnyCondition<class_AnyCondition>`.
