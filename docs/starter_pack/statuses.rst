.. _doc_example_statuses:

Statuses, traits and zones
==========================

What a character can be given, be immune to and walk into. Everything here is data with no code: a :ref:`StatusData<class_StatusData>` file, or a scene with an :ref:`EffectZone<class_EffectZone>`. The fields they are made from are covered in :ref:`doc_status_data`.

.. _doc_example_status_list:

Statuses
--------

These ship in ``character_system/starter_pack/`` as ``.tres`` files with no code. Duplicate one (right-click > Duplicate) and change the copy.

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
   * - Rooted
     - ``statuses/rooted.tres``
     - ``tags`` = rooted. ``duration`` = 3. ``blocks`` = movement, so the
       :ref:`CharacterMotor<class_CharacterMotor>` stops steering, jumping and moves.
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
   * - Stunned
     - ``statuses/stunned.tres``
     - ``tags`` = stunned. ``duration`` = 2. ``blocks`` = everything, which the
       :ref:`Brain<class_Brain>` answers to, so the character can't move, shoot or cast.
   * - Silenced
     - ``statuses/silenced.tres``
     - ``tags`` = silenced. ``duration`` = 4. ``blocks`` = spells, a name the example
       Fireball has in its Blocked By. Other abilities still work.
   * - Vampiric (passive)
     - ``statuses/vampiric.tres``
     - ``triggers`` = on ``dealt_damage``, a heal of 0 with a
       :ref:`HitAmount<class_HitAmount>` of 0.25: a quarter of each hit comes back.
   * - Bloodlust (passive)
     - ``statuses/bloodlust.tres``
     - ``triggers`` = on ``killed``, heal 15.
   * - Fire ward (passive)
     - ``statuses/fire_ward.tres``
     - ``triggers`` = on ``taking_damage``, ``react_to_statuses`` on, modify amount × 0.5 with
       a :ref:`HitCondition<class_HitCondition>` for fire. Other damage gets
       through.
   * - Sharpshooter (passive)
     - ``statuses/sharpshooter.tres``
     - ``triggers`` = on ``dealing_damage`` with a
       :ref:`HitCondition<class_HitCondition>` for ``head``: modify amount, percent 0.5,
       tag ``crit``. Give the head :ref:`Hurtbox<class_Hurtbox>` the tag.
   * - Lucky strikes (passive)
     - ``statuses/lucky_strikes.tres``
     - ``triggers`` = on ``dealing_damage`` with a
       :ref:`ChanceCondition<class_ChanceCondition>` (0.1, bonus stat ``crit_chance``): modify
       amount × 2, tag ``crit``.
   * - Executioner (passive)
     - ``statuses/executioner.tres``
     - ``triggers`` = on ``dealing_damage``, ``affects_other`` on, with an
       :ref:`AnyCondition<class_AnyCondition>` of "has the tag ``wet``" and "below half
       health": modify amount, percent 0.5.
   * - Berserk (passive)
     - ``statuses/berserk.tres``
     - ``modifiers`` = ``move_speed`` percent 0.3, with a
       :ref:`StatCondition<class_StatCondition>` on the modifier: only while ``strength`` is 5
       or more.
   * - Bleeding
     - ``statuses/bleeding.tres``
     - ``tags`` = bleed. ``duration`` = 5, ``max_stacks`` = 3. ``on_tick`` every second = damage
       0 with a :ref:`PoolAmount<class_PoolAmount>` of 2% of maximum health. The example
       sword applies it.

More ideas, built from the same fields. These aren't in the starter pack:

.. list-table::
   :header-rows: 1
   :widths: 25 75

   * - Idea
     - Fields to set
   * - Stoneskin
     - ``duration`` = 30. ``triggers`` = on ``taking_damage``, ``react_to_statuses`` on, a
       :ref:`ModifyAmountEffect<class_ModifyAmountEffect>` with ``add`` -3.
   * - Executioner (passive)
     - ``duration`` = 0. ``triggers`` = on ``dealing_damage``, affect other, with a
       :ref:`PoolBelowCondition<class_PoolBelowCondition>` (fraction 0.3) in the trigger's
       conditions, and a ModifyAmountEffect with ``percent`` 0.5. Affect other makes the
       condition check the victim, not the attacker.
   * - Pyromancer (passive)
     - ``duration`` = 0. ``modifiers`` = ``bonus_fire`` add 0.2: every fire hit and burn tick
       this character causes deals 20% more.
   * - Adrenaline (passive)
     - ``duration`` = 0. ``modifiers`` = ``move_speed`` percent 0.3, with a
       PoolBelowCondition (fraction 0.5) in the modifier's conditions: faster while badly
       hurt.
   * - Fury
     - ``duration`` = 6, ``stacking`` = STACK, ``max_stacks`` = 5. ``triggers`` = on
       ``dealing_damage``, a ModifyAmountEffect with ``percent`` 0.05 and ``per_stack`` on.
       A passive with a ``dealt_damage`` trigger applies it to its holder on each hit, so
       damage climbs while the attack keeps up.
   * - Antidote (an effect, not a status)
     - A :ref:`RemoveStatusEffect<class_RemoveStatusEffect>` with ``tag`` = poison removes
       every poison at once.
   * - Flaming blade (passive)
     - ``duration`` = 0. ``triggers`` = on ``dealt_damage``, affect other, an
       :ref:`ApplyStatusEffect<class_ApplyStatusEffect>` with Burning.
   * - Hunter's mark
     - ``duration`` = 10. ``modifiers`` = ``resist_physical`` -0.2. ``apply_conditions`` =
       :ref:`HasTagCondition<class_HasTagCondition>` (subject SOURCE, tag ``ranger``), so only
       rangers can apply it.

.. _doc_example_zones:

Zones
-----

These ship in ``character_system/starter_pack/zones/`` as scenes to drop into a level. Each is an :ref:`EffectZone<class_EffectZone>`; :ref:`doc_environment` covers how zones work.

.. list-table::
   :header-rows: 1

   * - Zone
     - What happens to a character
     - Built from
   * - Fire patch (``fire_patch.tscn``)
     - Set alight on walking in. The burn runs its course after they leave.
     - ``on_enter``: apply Burning
   * - Poison bog (``poison_bog.tscn``)
     - Poisoned on walking in.
     - ``on_enter``: apply Poisoned
   * - Water pool (``water_pool.tscn``)
     - Wet for as long as they stand in it, which puts out a burn and slows them.
     - ``status_while_inside``: Wet
   * - Healing pad (``healing_pad.tscn``)
     - Regenerating for as long as they stand on it.
     - ``status_while_inside``: Regenerating
   * - Ward circle (``ward_circle.tscn``)
     - Warded for as long as they stand in it: hits do half damage.
     - ``status_while_inside``: Warded
