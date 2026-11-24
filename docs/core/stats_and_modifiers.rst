.. _doc_stats_and_modifiers:

Stats, pools and health
=======================

Every number that a status, passive or item may change lives on the component that uses it: ``max_health`` on :ref:`Health<class_Health>`, ``move_speed`` on :ref:`CharacterMotor<class_CharacterMotor>`. The component lists its numbers in ``_stats()``, and the :ref:`ComponentManager<class_ComponentManager>` combines each one with the stat modifiers currently active on the host. A stat's value is ``(base + sum of adds) * (1 + sum of percents) * product of muls``.

The three parts of a modifier do different jobs. ``add`` is a flat change, such as +20 max health. ``percent`` is for bonuses that should add up: three items with +10% speed give +30%. ``mul`` applies to everything else, such as half speed while aiming. With ``move_speed`` 5 and modifiers ``add 1``, ``percent 0.5`` and ``mul 0.5``, the result is (5 + 1) × 1.5 × 0.5 = 4.5, whatever order they were added in.

A stat no component owns has a base of 0. Modifiers on it still add up, which is how ``bonus_fire`` works with nothing to set up, but nothing reads ``move_speed`` on a turret without a :ref:`CharacterMotor<class_CharacterMotor>`, so a modifier on it does nothing there.

.. source-file:: ../../character_system/core/stats/stat_modifier.gd

-  **Stats are open-ended.** A new component adds its own numbers by returning them from ``_stats()``; nothing else changes. :ref:`Health<class_Health>` turns each entry in its ``resistances`` into a ``resist_<type>`` stat, so ``resist_poison`` needs no code either.
-  **Your game's own stats need no script and no node.** The :ref:`ComponentManager<class_ComponentManager>` owns whatever you list in its **Stats** in the Inspector: ``strength``, ``level``, ``crit_chance``. See :ref:`doc_attributes`.
-  **Modifiers can be conditional.** A modifier with ``conditions`` only counts while they pass, checked on the character each time the stat is read: "+50% speed below half health" is a modifier with a :ref:`PoolBelowCondition<class_PoolBelowCondition>`. Such a stat isn't cached, and ``stat_changed`` isn't emitted when a condition flips, so UI that shows it should read it every frame.
-  **A number can be explained.** ``base_of(stat)`` is the value before modifiers, and ``modifiers_of(stat)`` lists every modifier on it with what added it, such as the :ref:`StatusData<class_StatusData>` or the item. A character sheet can show "Move speed 4.5: base 5, Boots +1, Haste +50%, Aiming ×0.5".
-  **Stacks are copies.** The same modifier resource can be added several times, once per status stack. ``remove_modifier`` removes one copy, so stacks unwind correctly.
-  **Totals are cached.** WalkMode reads ``move_speed`` every physics frame, so each total is worked out once and reused until a modifier for it changes, the component that owns it is added or removed, or a component calls ``update_stats()`` after changing its own number. Stats with a conditional modifier are the exception.
-  **Safe reads.** ``ComponentManager.stat_of(node, stat)`` reads a stat on any node, returning 0 for one with no manager, such as a wall. Inside a component, ``stat(name)`` reads its own host.
-  **Listening.** The manager emits ``stat_changed(stat_name)`` whenever a stat may have changed, in the same cases. :ref:`Health<class_Health>` uses it to keep health within a lowered maximum.

.. list-table::
   :header-rows: 1

   * - Stat
     - Owned by
     - Inspector field
   * - ``max_health``
     - :ref:`Health<class_Health>`
     - Max Health (100)
   * - ``resist_<type>``, e.g. ``resist_fire``
     - :ref:`Health<class_Health>`. :ref:`DamageEffect<class_DamageEffect>` reads the target's: 1 or more is immune, and a negative value is a weakness
     - Resistances, e.g. fire: 0.5
   * - ``bonus_<type>``, e.g. ``bonus_fire``
     - Nobody: it starts at 0. :ref:`DamageEffect<class_DamageEffect>` reads the source's as a percentage, so 0.2 is 20% more fire damage dealt
     - None. Give it with a :ref:`StatModifier<class_StatModifier>`
   * - ``move_speed``
     - :ref:`CharacterMotor<class_CharacterMotor>`
     - Move Speed (5)
   * - ``jump_velocity``
     - :ref:`CharacterMotor<class_CharacterMotor>`
     - Jump Velocity (4.5)
   * - ``air_jumps``
     - :ref:`AirMode<class_AirMode>`, under the motor
     - Air Jumps (1)
   * - ``cooldown_speed``
     - :ref:`Abilities<class_Abilities>`
     - Cooldown Speed (1)
   * - ``max_<pool>`` and ``<pool>_regen``, e.g. ``max_mana`` and ``mana_regen``
     - The :ref:`Pool<class_Pool>` with that name
     - Max Value (100) and Regen (0)
   * - Any name you choose
     - The :ref:`ComponentManager<class_ComponentManager>` itself
     - Stats, e.g. strength: 10

Your own components add more: any name a component returns from ``_stats()`` is a stat. Movement modes and moves can own stats the same way; the motor adds theirs to its own. :ref:`doc_extending_names` shows how.

**Stats and damage.** Stats reach a hit in three ways. The source's ``bonus_<type>`` and the target's ``resist_<type>`` are read by every :ref:`DamageEffect<class_DamageEffect>`. Any stat can scale an effect's number through a :ref:`StatAmount<class_StatAmount>`, such as 2 damage per point of ``strength``; see :ref:`doc_amounts`. For a bonus with a condition, such as "+50% against wet targets", a status with a ``dealing_damage`` trigger and a :ref:`ModifyAmountEffect<class_ModifyAmountEffect>` changes each hit before it lands.

.. _doc_attributes:

Stats of your own
-----------------

Select the character's :ref:`ComponentManager<class_ComponentManager>` and add entries to **Stats**: a name and a base value each. Code changes a base with ``set_base()`` and ``add_base()`` on the manager:

.. code-block:: gdscript

   var manager := ComponentManager.of(player)
   manager.add_base(&"level", 1)       # Level up; everything scaled by level follows.
   manager.set_base(&"strength", 14)

A stat listed there is like any other: statuses and gear change it, effects scale with it, conditions test it, and the :ref:`editor warnings <doc_editor_warnings_for_names>` know its name once a saved scene lists it. If a component owns a stat with the same name, the component's value is used.

.. _doc_pools:

Pools
-----

A :ref:`Pool<class_Pool>` is a number that's spent and regained: health, mana, stamina, energy, rage. A character has one per kind, each named in the Inspector. Everything that uses up or gives back a resource works on pools, so a new resource is a new Pool node and no code.

.. source-file:: ../../character_system/core/pool.gd

-  **Spending.** An ability's ``costs`` take from pools by name, a :ref:`ChangePoolEffect<class_ChangePoolEffect>` adds or takes from any effect list, and code calls ``spend()``, which takes nothing unless the pool has enough.
-  **Two stats each.** ``max_<pool>`` and ``<pool>_regen`` go through the manager, so a status can raise the maximum or the refill rate. The current amount is cut down when the maximum drops.
-  **Regen that waits.** ``regen_delay`` restarts every time the pool is spent or drained.
-  **A shield is a pool.** With ``absorbs_damage`` on, the pool hears ``absorbing_damage``, the last step before health, and takes what it can from the hit. ``absorbed_types`` limits it to some damage types. Regen and a delay make it recharge out of combat.
-  **Running out.** ``status_while_empty`` is on the character for as long as the pool is empty, and comes off when it has something again: Exhausted on a stamina pool, say. What the character can't do meanwhile is that status's ``blocks``. The character needs a :ref:`Statuses<class_Statuses>` component for it.
-  **Health is the pool named** ``health``. :ref:`Health<class_Health>` extends Pool, so costs, ``max_health``, ``health_regen``, :ref:`PoolAmount<class_PoolAmount>` and :ref:`PoolBelowCondition<class_PoolBelowCondition>` treat it like any other. Its status while empty is the death status; see :ref:`doc_health`.
-  **Several per host.** ``find()`` returns the first component of a type, so pools are looked up by name with ``Pool.named(node, &"mana")``.

.. _doc_health:

Health
------

.. source-file:: ../../character_system/core/health.gd

**Health is a pool.** It is the :ref:`Pool<class_Pool>` named ``health``, so everything that works on pools works on health: ``max_health`` and ``health_regen`` are stats, an ability can list ``health`` in its costs, a :ref:`PoolAmount<class_PoolAmount>` or :ref:`PoolBelowCondition<class_PoolBelowCondition>` reads it, and a bar that shows a pool shows health. What it adds is resistances and death.

**Death is a status.** At zero the character gets the status in **Death Status**, and keeps it until ``revive()``. Health itself only stops changing while dead. Everything else a dead character can't do is written on that status, in its ``blocks`` (see :ref:`what a status blocks <doc_stuns>`). The default, ``core/statuses/dead.tres``, blocks ``everything``, ``healing`` and ``targeting`` and ends timed statuses: the dead can't act or be healed, shots pass through them, and AI leaves them alone. Give a boss a status that blocks less for a last stand, make a "Downed" status for a game with revives, or clear the field for a game in which nothing dies.

What death means for the game (ragdoll, loot drop, game over) is decided by whatever connects to ``died``; every component on the character also hears it as the ``died`` event, and whoever dealt the killing blow hears ``killed``. ``revive()`` sends ``revived``.

For a shield that takes damage before health does, add a :ref:`Pool<class_Pool>` with Absorbs Damage on; see :ref:`doc_pools`.

Health stays full until the manager sends ``started``, the moment every component has had its chance to start. Innate passives such as "+20 max health" are applied by then, so a character starts at its buffed maximum whatever the node order. After that, raising the maximum doesn't heal.
