.. _doc_example_abilities:

Abilities
=========

What a character can cast. These ship in ``character_system/starter_pack/abilities/`` as :ref:`AbilityData<class_AbilityData>` files with no code. Put one in a slot of a character's :ref:`Abilities<class_Abilities>`, or duplicate it and change the copy; :ref:`doc_abilities` covers every field.

.. list-table::
   :header-rows: 1

   * - Ability
     - What the player gets
     - Built from
   * - Fireball (``fireball.tres``)
     - Costs 20 mana and takes half a second to cast, with a 2 second cooldown. Launches a fireball that bursts for fire damage growing with ``spell_power`` and sets alight what it hits. Being silenced or stunned during the cast stops it, and nothing is spent.
     - **Costs**, **Cast Time**, and a :ref:`LaunchProjectileEffect<class_LaunchProjectileEffect>` in **User Effects**. **Blocked By** lists ``abilities`` and ``spells``, so the Silenced status stops it.
   * - Shockwave (``shockwave.tres``)
     - Costs 15 mana. Hits everyone within 6 metres for 15 and throws them back, friend or foe. Two charges, each back after 6 seconds.
     - :ref:`RadiusTargeting<class_RadiusTargeting>` with Hostile Only off, a :ref:`DamageEffect<class_DamageEffect>` and a :ref:`KnockbackEffect<class_KnockbackEffect>`; **Charges** 2
   * - Second wind (``second_wind.tres``)
     - Heals the user for 30. 10 second cooldown.
     - One :ref:`HealEffect<class_HealEffect>`
   * - Sprint (``sprint.tres``)
     - Gives the user the Haste status. 15 second cooldown.
     - One :ref:`ApplyStatusEffect<class_ApplyStatusEffect>`

Sprint the ability is a burst on a cooldown. Running for as long as a button is held, paid for from a stamina pool, is the :ref:`Sprint<class_Sprint>` component in ``starter_pack/scripts/``; :ref:`doc_extending_component` walks through it.

To give a weapon an ability, add it to the item's :ref:`Grants<class_Grants>`: the fire staff grants Fireball while it is held (see :ref:`doc_stats_and_abilities_from_equipment`).
