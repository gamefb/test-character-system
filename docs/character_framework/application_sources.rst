.. _doc_application_sources:

Application sources
===================

Every source applies statuses the same way: it builds an :ref:`EffectContext<class_EffectContext>` and runs a list of effects with ``Effect.apply_all()``. Only effects, :ref:`Grants<class_Grants>` and :ref:`EffectZone<class_EffectZone>` call ``Statuses.add()``, ``remove()`` or ``drop_hold()`` directly.

.. list-table::
   :header-rows: 1

   * - Source
     - Target
     - Mechanism
     - Example
   * - Character
     - Itself, always
     - ``Statuses.innate``
     - A fire elemental is immune to fire
   * - Equipment
     - Its wielder
     - :ref:`Grants<class_Grants>` on the item
     - Ring of haste grants Haste while worn
   * - Equipment
     - Whatever it hits
     - ``effects`` on :ref:`Hitscan<class_Hitscan>`, :ref:`MeleeSweep<class_MeleeSweep>` or a :ref:`LaunchProjectileEffect<class_LaunchProjectileEffect>`
     - Flaming sword applies Burning
   * - Projectile
     - What it hits, and everything near the impact
     - ``effects`` and ``blast_effects`` on the :ref:`Projectile<class_Projectile>`
     - A fireball burns its target and scorches everyone around it
   * - Character
     - Another character or itself
     - ``AbilityData.effects`` and ``user_effects`` through :ref:`Abilities<class_Abilities>`
     - Player casts Slow on an AI. A friendly AI casts Haste on the player.
   * - Character
     - Itself, for the length of a cast
     - ``AbilityData.status_while_casting``
     - A mage is slowed while casting
   * - Consumable
     - Whoever uses it
     - ``ItemData.use_effects`` through ``Inventory.use()``
     - An elixir grants Haste
   * - Status
     - Its holder
     - ``on_apply``, ``on_tick``, ``on_remove``
     - Burning deals fire damage each second
   * - Status
     - The other party in an event
     - :ref:`StatusTrigger<class_StatusTrigger>` with ``affects_other``
     - Thorns damages the attacker
   * - Status
     - A hit in progress
     - :ref:`StatusTrigger<class_StatusTrigger>` + :ref:`ModifyAmountEffect<class_ModifyAmountEffect>`
     - Stoneskin reduces each hit by 3
   * - Environment
     - Anything that enters it
     - :ref:`EffectZone<class_EffectZone>`
     - A fire patch applies Burning. Water applies Wet.

.. _doc_environment:

Environment
-----------

.. source-file:: ../../character_system/character/world/effect_zone.gd

-  **"While inside" status** (deep water, a healing aura): set ``status_while_inside`` to a status with duration 0. Each zone a body stands in is one hold, so leaving one of two overlapping pools keeps it wet. The zone only drops holds for bodies that accepted the status, so a refused body never loses a hold that another source gave it.
-  **One-shot hazard** (a fire patch): ``on_enter`` = :ref:`ApplyStatusEffect<class_ApplyStatusEffect>` with a timed status such as Burning.
-  **Surfaces created at runtime**, such as a puddle left by a water spell, are an :ref:`EffectZone<class_EffectZone>` scene spawned by a :ref:`SpawnSceneEffect<class_SpawnSceneEffect>`. When the puddle is freed, everyone still standing in it loses its status. Statuses can therefore create environment that applies further statuses.

.. _doc_a_full_chain_end_to_end:

A full chain, end to end
------------------------

This chain uses two of the status ideas from :ref:`doc_example_statuses`, Flaming blade and Stoneskin, alongside the shipped Burning and Wet.

1. The player equips a rifle with :ref:`Hitscan<class_Hitscan>` [damage 10] and a ring with :ref:`Grants<class_Grants>` [Flaming blade].
2. The player fires at an enemy's head. :ref:`Trigger<class_Trigger>` emits ``fired``, and :ref:`Hitscan<class_Hitscan>` hits the enemy's head :ref:`Hurtbox<class_Hurtbox>`, which sets ``magnitude`` to 2.
3. :ref:`DamageEffect<class_DamageEffect>` works out 20 damage and sends ``taking_damage``. The enemy's Stoneskin adds -3 to the hit's totals, and the hit lands for 17.
4. The enemy's :ref:`Health<class_Health>` drops by 17, and the player's :ref:`Statuses<class_Statuses>` receives ``dealt_damage``.
5. Flaming blade's trigger runs :ref:`ApplyStatusEffect<class_ApplyStatusEffect>` on the enemy, which gains Burning.
6. Burning ticks fire damage with the player as source. Stoneskin reacts to the ticks too, because its trigger has ``react_to_statuses`` on. The ticks set off nothing else, so the chain ends.
7. The enemy walks into water. :ref:`EffectZone<class_EffectZone>` applies Wet, which removes Burning and blocks it while the enemy stays wet.
