.. _doc_stats_and_modifiers:

Stats and modifiers
===================

Every number that a status, passive or item may change lives on the component that uses it: ``max_health`` on :ref:`Health<class_Health>`, ``move_speed`` on :ref:`Movement<class_Movement>`. The component lists its numbers in ``_stats()``, and the :ref:`ComponentManager<class_ComponentManager>` combines each one with the stat modifiers currently active on the host. A stat's value is ``(base + sum of adds) * product of muls``.

Without the component the number has no purpose, so it has no value either: a modifier on ``move_speed`` does nothing to a turret without :ref:`Movement<class_Movement>`, and reading it returns 0.

.. source-file:: ../../character_system/resources/stats/stat_modifier.gd

-  **Stats are open-ended.** A new component adds its own numbers by returning them from ``_stats()``; nothing else changes. :ref:`Health<class_Health>` turns each entry in its ``resistances`` into a ``resist_<type>`` stat, so ``resist_poison`` needs no code either.
-  **Stacks are copies.** The same modifier resource can be added several times, once per status stack. ``remove_modifier`` removes one copy, so stacks unwind correctly.
-  **Totals are cached.** Movement reads ``move_speed`` every physics frame, so each total is worked out once and reused until a modifier for it changes, the component that owns it is added or removed, or a component calls ``update_stats()`` after changing its own number.
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
     - :ref:`Health<class_Health>`; :ref:`DamageEffect<class_DamageEffect>` clamps it to 0 to 1
     - Resistances, e.g. fire: 0.5
   * - ``move_speed``
     - :ref:`Movement<class_Movement>`
     - Move Speed (5)
   * - ``jump_velocity``
     - :ref:`Movement<class_Movement>`
     - Jump Velocity (4.5)

Damage buffs are not a stat. A status with a ``dealing_damage`` trigger and a :ref:`ModifyAmountEffect<class_ModifyAmountEffect>` changes each hit before it lands, which also allows conditions such as "+50% against wet targets".
