.. _doc_effects_statuses_and_passives:

Effects, statuses and passives
==============================

An :ref:`Effect<class_Effect>` is one instant change to a target; a status is a container of effects and stat modifiers that lives on a character for a while. A passive is a status with no duration. A :ref:`Condition<class_Condition>` decides whether an effect runs, or whether a status can be applied, and an :ref:`Amount<class_Amount>` works out an effect's number from stats, health or the hit. Together these cover damage over time, buffs, auras, on-hit procs, shields, immunities, crits, damage that grows with a character, conditional bonuses and equipment bonuses.

.. _doc_effects:

Effects
-------

.. source-file:: ../../character_system/core/effect_context.gd

.. source-file:: ../../character_system/core/effects/effect.gd

To make a new effect, extend :ref:`Effect<class_Effect>`, add ``@export`` fields for its settings, and write ``_execute()``. Conditions then work on it automatically. An effect with a number extends :ref:`AmountEffect<class_AmountEffect>`, which is all of this:

.. source-file:: ../../character_system/core/effects/amount_effect.gd

:ref:`doc_extending_effect` walks through one of each.

.. _doc_damage_pipeline:

How a hit is worked out
-----------------------

.. source-file:: ../../character_system/core/effects/damage_effect.gd

Every hit goes through the same steps, in the same order:

.. list-table::
   :header-rows: 1
   :widths: 6 40 54

   * - Step
     - What happens
     - What plugs in here
   * - 1
     - The number starts as ``amount`` plus everything in ``scaling``, times ``magnitude``
     - :ref:`Amounts <doc_amounts>`, headshot multipliers, status stacks
   * - 2
     - The source's ``bonus_<type>`` stat is added as a percentage
     - "+20% fire damage" on gear, as a :ref:`StatModifier<class_StatModifier>`
   * - 3
     - ``dealing_damage`` is sent to the source and ``taking_damage`` to the target. Listeners
       change ``add``, ``percent`` and ``mul`` on the context
     - Crits, damage buffs, armour, shields that halve
   * - 4
     - The totals are applied once: (amount + add) × (1 + percent) × mul
     -
   * - 5
     - The target's ``resist_<type>`` stat takes its share: 0.5 halves, 1 is immune, a
       negative value is a weakness
     - Resistances on :ref:`Health<class_Health>`, statuses and gear
   * - 6
     - ``absorbing_damage`` is sent to the target with the final number in ``amount``
     - A :ref:`Pool<class_Pool>` that absorbs damage; your own barriers
   * - 7
     - Health loses what's left
     -
   * - 8
     - ``dealt_damage`` is sent to the source and ``took_damage`` to the target. A killing
       blow also sends ``died`` to the target and ``killed`` to the source
     - Thorns, life steal, on-hit and on-kill effects, damage numbers

Because step 3 only collects changes and step 4 applies them, the result doesn't depend on which status was applied first: armour of -3 and a shield of ×0.5 turn a hit of 10 into 3.5 in either order. Resistance is capped at 1 and the final amount is never negative, so stacking resistances can block damage but never turn it into healing. A target that is already dead is left alone: no damage, and no events.

The hit also says what kind it was. ``damage_type`` is the effect's type, ``tags`` are labels from the :ref:`Hurtbox<class_Hurtbox>` that was hit (``head``), from the effect (``melee``) and from statuses (``crit``), and ``position`` is where a ray or projectile landed. A :ref:`HitCondition<class_HitCondition>` tests the first two, so a status can react to fire only, or to headshots only.

.. source-file:: ../../character_system/core/effects/heal_effect.gd

Healing goes through steps 1, 3, 4, 7 and 8 with its own events: ``giving_healing`` and ``receiving_healing`` before, ``gave_healing`` and ``received_healing`` after. A curse that halves healing received is a trigger on ``receiving_healing``, built the same way as a shield.

.. _doc_amounts:

Amounts
-------

An effect's plain number is the same for everyone. Its ``scaling`` list makes it depend on who is involved: each :ref:`Amount<class_Amount>` in it is worked out when the effect runs and added on. :ref:`DamageEffect<class_DamageEffect>`, :ref:`HealEffect<class_HealEffect>` and :ref:`ChangePoolEffect<class_ChangePoolEffect>` all have one, from their base class :ref:`AmountEffect<class_AmountEffect>`, and so does any effect of your own that extends it.

.. source-file:: ../../character_system/core/amounts/amount.gd

.. source-file:: ../../character_system/core/amounts/stat_amount.gd

.. list-table::
   :header-rows: 1

   * - Want
     - Amount plus scaling
   * - A sword that hits harder with strength
     - 10 + :ref:`StatAmount<class_StatAmount>` (``strength``, of SOURCE, 2 per point)
   * - A spell that grows with level on a curve
     - 0 + StatAmount (``level``, with a curve from level 1 to the top level)

The stats come from the component that owns them, or from the :ref:`ComponentManager<class_ComponentManager>`'s Stats for stats of your own; see :ref:`doc_attributes`. A status tick's source is whoever applied the status, so a burn grows with the caster's ``spell_power``, not the victim's.

The character framework adds amounts that read a pool, the hit being worked out, or dice: see :ref:`doc_more_amounts`.

Other effects
-------------

.. source-file:: ../../character_system/core/effects/apply_status_effect.gd

.. source-file:: ../../character_system/core/effects/remove_status_effect.gd

.. source-file:: ../../character_system/core/effects/modify_amount_effect.gd

:ref:`ModifyAmountEffect<class_ModifyAmountEffect>` is how statuses take part in step 3 of the pipeline. :ref:`DamageEffect<class_DamageEffect>` announces the hit before it lands, a status trigger reacts with this effect, and the effect adds to the totals of the pending hit through ``ctx.cause``. ``per_stack`` makes each stack of the status count, and ``tag`` labels the hit, such as ``crit``.

The character framework adds effects that change a pool, shove the target, spawn a scene and launch a projectile: see :ref:`doc_more_effects`.

.. _doc_conditions:

Conditions
----------

.. source-file:: ../../character_system/core/conditions/condition.gd

.. source-file:: ../../character_system/core/conditions/has_tag_condition.gd

``_test(node) != negate`` is a compact way to flip the result: when ``negate`` is true, true becomes false and false becomes true. ``Condition.all_pass()`` is shared by effects and by status apply conditions, described under Status data.

.. list-table::
   :header-rows: 1

   * - Condition
     - Passes when
     - Typical use
   * - :ref:`HasTagCondition<class_HasTagCondition>`
     - The node has a status with the tag
     - Bonus damage against wet targets

A list of conditions needs all of them to pass. The character framework adds conditions on pools, stats, hostility, chance and the hit, and :ref:`AnyCondition<class_AnyCondition>` for alternatives: see :ref:`doc_more_conditions`. The same conditions work on effects, on status triggers, on whether a status can be applied, on :ref:`stat modifiers <doc_stats_and_modifiers>` and on whether an ability can be used.

.. _doc_status_data:

Status data
-----------

.. source-file:: ../../character_system/core/statuses/status_trigger.gd

.. source-file:: ../../character_system/core/statuses/status_data.gd

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
   * - ``blocks``
     - What the character can't do, or can't have done to it, while active (see
       :ref:`what a status blocks <doc_stuns>`)
     - Stunned blocks everything; Silenced blocks spells; Dead blocks everything, healing and
       targeting
   * - ``removes_timed``
     - Ends every status with a duration when applied
     - Death ends burning and poison; passives stay for a revive
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
     - Reactions to events, each with its own conditions
     - Thorns: damage the attacker when hit
   * - ``tags``, ``removes_tags``
     - Interactions between statuses
     - Wet puts out Burning when it is added
   * - ``stacking``, ``max_stacks``
     - Reapply rules
     - Poisoned stacks to 3, each stack adding tick damage

.. _doc_stuns:

What a status blocks
--------------------

**A status says what it blocks.** Everything that can be stopped answers to one or more names, listed in its **Blocked By**, and a status stops it by listing one of those names in its **Blocks**. Nothing that gets stopped knows about stuns, roots or death; it only knows its own names. A new status therefore needs no changes anywhere else.

.. list-table::
   :header-rows: 1

   * - Name
     - What answers to it
     - A status that blocks it
   * - ``everything``
     - The :ref:`Brain<class_Brain>`: ``move_dir`` reads as zero and no action counts as pressed. The motor, weapons, weapon switching and abilities all read the brain, so this one name stops all of them, for a player and an AI alike
     - Stunned, frozen, asleep, Dead
   * - ``movement``
     - The :ref:`CharacterMotor<class_CharacterMotor>`: no steering, jumping or moves; see :ref:`doc_movement_statuses_events_cooldowns`
     - Rooted
   * - ``weapons``
     - Every :ref:`Trigger<class_Trigger>`
     - Disarmed
   * - ``abilities``
     - Every :ref:`AbilityData<class_AbilityData>`
     - Dazed
   * - ``damage``, ``healing``
     - :ref:`DamageEffect<class_DamageEffect>` and :ref:`HealEffect<class_HealEffect>` on this character
     - Invulnerable; Dead blocks healing
   * - ``targeting``
     - Shots, the player's crosshair, :ref:`RadiusTargeting<class_RadiusTargeting>` and the example AI
     - Dead, or a stealth status

Add names of your own to sort things into kinds. The example Fireball answers to ``abilities`` and ``spells``, and Silenced blocks ``spells``, so it stops the Fireball and leaves Sprint alone. The blocks are counted on the :ref:`ComponentManager<class_ComponentManager>`: ``block()`` and ``unblock()`` do from code what a status does, for a cutscene, and ``manager.blocks`` shows what is blocked right now.

.. _doc_events:

Events
------

An event is a name and an :ref:`EffectContext<class_EffectContext>`, sent to one host. Each event is an ordinary Godot signal on the host's manager: a component connects to the ones it wants with ``on()``, code outside the host connects with ``event()``, and :ref:`Statuses<class_Statuses>` passes every event on to status triggers. The damage and healing events are built in, :ref:`Health<class_Health>` sends ``died``, ``killed`` and ``revived``, :ref:`Abilities<class_Abilities>` sends three, the manager sends ``started``, :ref:`Inventory<class_Inventory>` sends ``inventory_changed``, and the :ref:`CharacterMotor<class_CharacterMotor>` sends one each time a movement mode or move starts or ends. Status triggers only react to events that carry a context, so ``started``, ``revived`` and ``inventory_changed`` reach components but never triggers, and ``died`` reaches triggers only when something dealt the killing blow. Any system can add more with one line, such as ``ComponentManager.notify(host, &"jumped")``. ``notify()`` gives the event a context with the host as the target, so triggers react to it; pass your own :ref:`EffectContext<class_EffectContext>` as a third argument to say who caused it.

.. list-table::
   :header-rows: 1

   * - Event
     - Sent to
     - When
     - Typical use
   * - ``dealing_damage``
     - Attacker
     - Before damage lands; ``add``, ``percent`` and ``mul`` can be changed
     - Crits, damage buffs, "+50% damage to wet targets"
   * - ``taking_damage``
     - Victim
     - Before damage lands; ``add``, ``percent`` and ``mul`` can be changed
     - Shields, flat armor
   * - ``absorbing_damage``
     - Victim
     - The final number is in ``amount``, which can be lowered
     - A :ref:`Pool<class_Pool>` soaking up damage before health
   * - ``dealt_damage``
     - Attacker
     - After damage lands; ``amount`` is what landed
     - On-hit procs, lifesteal
   * - ``took_damage``
     - Victim
     - After damage lands
     - Thorns, "enrage when hit", damage numbers
   * - ``giving_healing``, ``receiving_healing``
     - Healer, and whoever is healed
     - Before healing lands; it can be changed as damage can
     - "+20% healing done", a curse that halves healing received
   * - ``gave_healing``, ``received_healing``
     - Healer, and whoever is healed
     - After healing lands
     - "Gain a shield whenever you're healed"
   * - ``died``
     - The character that died
     - Its health reaches zero
     - Ending timed statuses, on-death effects
   * - ``killed``
     - Whoever dealt the killing blow
     - Right after ``died``; the context's target is who died
     - Heal on kill, kill streaks, experience
   * - ``revived``
     - The character brought back; no context
     - ``Health.revive()`` on a dead character
     - Standing back up
   * - ``ability_cast_started``, ``ability_used``, ``ability_interrupted``
     - The character using the ability
     - A cast begins, an ability's effects run, a cast is cut short; ``origin`` is the
       :ref:`AbilityData<class_AbilityData>`
     - "After each spell, your next shot burns"
   * - ``weapon_started``, ``weapon_fired``, ``weapon_interrupted``
     - The character using the weapon
     - A press is accepted, the shot happens, a wind-up is cut short; ``origin`` is the
       :ref:`ItemData<class_ItemData>`. See :ref:`doc_weapon_events`
     - Playing a swing, a passive that heals on every shot
   * - ``started``
     - Every component on the host; no context
     - All its components have had the chance to start
     - :ref:`Health<class_Health>` settling at full health
   * - ``inventory_changed``
     - Every component on the host; no context
     - Something was added to or removed from the Inventory
     - Equipment unequipping a dropped item, WeaponSwitch drawing a weapon
   * - ``<mode>_entered``, ``<mode>_exited``
     - The moving character
     - A movement mode takes over or hands over, e.g. ``walk_mode_entered`` on landing
     - Landing shockwaves, effects on take-off. See :ref:`doc_movement_statuses_events_cooldowns`
   * - ``<move>_started``, ``<move>_finished``
     - The moving character
     - A layered move starts or ends, e.g. ``dash_move_started``
     - Dashes that cost health or leave a trail of fire

**Hearing an event.** Who is listening decides how:

.. list-table::
   :header-rows: 1

   * - Listener
     - How
     - Ends
   * - A status
     - A :ref:`StatusTrigger<class_StatusTrigger>` with the event's name, in the Inspector
     - With the status
   * - A component, for its own host
     - ``on(&"took_damage", _on_took_damage)`` in ``_start()``
     - When the component stops
   * - A component, for another host, such as an item for its wielder
     - ``on(&"killed", _on_wielder_killed, wielder)``
     - When the component stops
   * - Anything else, such as a HUD
     - ``ComponentManager.of(player).event(&"took_damage").connect(_on_player_hurt)``
     - With ``disconnect()``, or when the listener is freed
   * - Something that watches the whole level
     - ``WorldEvents.event(&"died").connect(_on_anything_died)``
     - With ``disconnect()``, or when the listener is freed
   * - Something that wants every event of one host, such as a combat log
     - ``manager.event_sent.connect(_on_event)``
     - With ``disconnect()``, or when the listener is freed

**Signals.** ``event()`` and ``WorldEvents.event()`` return a ``Signal``, so everything Godot's signals do works on events: ``connect()`` with ``CONNECT_ONE_SHOT``, ``await manager.event(&"died")``, ``bind()``, and no clean-up, because Godot drops a connection when the listener is freed. A method of the manager's own listeners takes the context; a world listener takes the host and the context.

**Order.** ``event_sent`` goes first, which is where :ref:`Statuses<class_Statuses>` runs its triggers. Then the event's own signal calls its listeners in the order they connected, and last come the :ref:`WorldEvents<class_WorldEvents>` listeners. So a component that listens with ``on()`` sees a hit after every status has changed it, as :ref:`Pool<class_Pool>` does. There are no priorities: a listener that must come before the statuses connects to ``event_sent``.

.. source-file:: ../../character_system/core/world_events.gd

WorldEvents is for things that belong to no one character: experience for kills, quest counters, a kill feed, achievements. It needs no node in the scene and no autoload, and its listeners outlive a change of scene for as long as their object does.

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
     - A Fireproof passive with ``immune_to`` = ``fire``, given by the item's :ref:`Grants<class_Grants>`
   * - Targets with full fire resistance can't burn
     - Burning: ``apply_conditions`` = StatCondition: stat ``resist_fire``, value 1, negate on
   * - Only rangers can apply Hunter's mark
     - Hunter's mark: ``apply_conditions`` = HasTagCondition: subject SOURCE, tag ``ranger``
   * - Execution marks only land on wounded targets
     - Execution mark: ``apply_conditions`` = PoolBelowCondition: fraction 0.25

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
   * - Item, through :ref:`Grants<class_Grants>`
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
-  **Refusals.** A passive is checked once, when it is added. Innate passives are checked when the character starts. An item passive that is refused is not retried until the item is equipped again, and :ref:`Grants<class_Grants>` only drops holds on the passives it was given.
-  **Death.** Passives survive death, because the Dead status only ends statuses that have a duration, so a revived character keeps its traits and item passives.

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

.. source-file:: ../../character_system/core/statuses/statuses.gd

The rules this component enforces:

-  **Refusals come first.** ``add()`` checks immunities (``immune_to`` on statuses the character already has) and ``apply_conditions`` before anything else. A refused status changes nothing: ``add()`` returns false and ``refused`` is emitted.
-  **One instance per status.** Reapplying refreshes the duration. With ``STACK`` it also adds a stack up to ``max_stacks``, and modifiers and effect magnitude scale with stacks.
-  **Timed statuses are removed; permanent ones lose a hold.** A status with duration 0 counts its holds: each item, zone or innate entry that adds it is one hold, and ``drop_hold()`` drops one. Two rings granting Haste keep it until both come off. Cleanses use ``remove()``, which ends it outright.
-  **Statuses don't set off reactions.** Anything a status does is marked ``from_status``, and triggers ignore it unless ``react_to_statuses`` is on. This one rule stops feedback loops, such as two Thorns holders bouncing damage forever. Shields turn it on so they also block burn ticks. Triggers that do react to statuses can't loop forever either: a chain is cut once it is ``EffectContext.MAX_DEPTH`` triggers long, with a warning.
-  **A trigger's conditions are checked once.** They decide whether the trigger runs at all, before any of its effects. A :ref:`ChanceCondition<class_ChanceCondition>` there rolls once, so a crit's bonus damage and its ``crit`` tag always go together.
-  **Credit is kept.** Damage from a status tick carries the original applier as ``source``, so kill credit and the applier's ``dealing_damage`` triggers still work.
-  **Death ends timed statuses only.** :ref:`Statuses<class_Statuses>` hears the ``died`` event and removes timed statuses. Burning stops on a corpse, but racial and equipment passives stay, so a revived character keeps them.
-  **Removing the component removes its statuses.** ``_stop()`` takes every status off, so no stat modifier is left behind on the manager. It doesn't run ``on_remove``, which is for a status that ends: a character that is freed, by despawning or by a change of level, doesn't set off its "bursts when it ends" statuses.
-  **Passives cost nothing per frame.** ``_process()`` only runs while a status has a ``duration`` or a ``tick_interval``, so a crowd whose only statuses are traits and item passives adds no per-frame work.
