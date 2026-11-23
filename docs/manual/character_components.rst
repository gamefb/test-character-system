.. _doc_character_components:

Character components
====================

Each component owns one concern and is optional. The table lists the standard set; the code for each follows.

.. list-table::
   :header-rows: 1

   * - Component
     - Owns
     - Requires
     - Uses if present
     - Signals
   * - :ref:`Statuses<class_Statuses>`
     - Active statuses and passives (see Effects, statuses and passives)
     - none
     - none
     - ``changed``, ``refused``
   * - :ref:`Pool<class_Pool>`
     - One spendable number, such as mana, stamina or a shield, and the status the character
       has while it is empty (see :ref:`doc_pools`)
     - none
     - :ref:`Statuses<class_Statuses>`, for that status
     - ``changed``, ``emptied``
   * - :ref:`Health<class_Health>`
     - The pool named ``health``, with resistances and death
     - none
     - :ref:`Statuses<class_Statuses>`, for the death status
     - ``changed``, ``emptied``, ``died``
   * - :ref:`Brain<class_Brain>`
     - Intent: move direction, aim point, held and just-pressed buttons; nothing while a
       status blocks ``everything``
     - none
     - none
     - none
   * - :ref:`CharacterMotor<class_CharacterMotor>`
     - Turning intent into motion through its movement modes and moves (see Movement),
       ``move_speed``, ``jump_velocity``, pushes
     - :ref:`Brain<class_Brain>`
     - none
     - ``mode_changed``
   * - :ref:`MouseLook<class_MouseLook>`
     - Turning the player and its camera with the mouse; capturing the mouse
     - none (uses the character's Camera3D)
     - none
     - none
   * - :ref:`Faction<class_Faction>`
     - Team and hostility
     - none
     - none
     - none
   * - :ref:`Inventory<class_Inventory>`
     - Item stacks; sends the inventory_changed event
     - none
     - none
     - ``changed``
   * - :ref:`Abilities<class_Abilities>`
     - Ability slots, cooldowns, charges, costs and casts
     - :ref:`Brain<class_Brain>`
     - :ref:`Pool<class_Pool>` for costs, :ref:`Statuses<class_Statuses>`
     - ``used``, ``cast_started``, ``cast_interrupted``, ``failed``
   * - :ref:`Equipment<class_Equipment>`
     - Equipped item scenes (see Equipment system)
     - none
     - :ref:`Brain<class_Brain>`, :ref:`Inventory<class_Inventory>` (through the item's components); with an Inventory, everything equipped is also carried
     - ``changed``
   * - :ref:`WeaponSwitch<class_WeaponSwitch>`
     - Which carried weapon is held (see Switching weapons)
     - Brain, Inventory, Equipment
     - none
     - none

Every host also needs one :ref:`ComponentManager<class_ComponentManager>`. A component whose requirement is missing waits instead of failing: it starts as soon as the requirement is added.

.. _doc_health:

Health
------

.. source-file:: ../../character_system/core/health.gd

**Health is a pool.** It is the :ref:`Pool<class_Pool>` named ``health``, so everything that works on pools works on health: ``max_health`` and ``health_regen`` are stats, an ability can list ``health`` in its costs, a :ref:`PoolAmount<class_PoolAmount>` or :ref:`PoolBelowCondition<class_PoolBelowCondition>` reads it, and a bar that shows a pool shows health. What it adds is resistances and death.

**Death is a status.** At zero the character gets the status in **Death Status**, and keeps it until ``revive()``. Health itself only stops changing while dead. Everything else a dead character can't do is written on that status, in its ``blocks`` (see :ref:`what a status blocks <doc_stuns>`). The default, ``core/statuses/dead.tres``, blocks ``everything``, ``healing`` and ``targeting`` and ends timed statuses: the dead can't act or be healed, shots pass through them, and AI leaves them alone. Give a boss a status that blocks less for a last stand, make a "Downed" status for a game with revives, or clear the field for a game in which nothing dies.

What death means for the game (ragdoll, loot drop, game over) is decided by whatever connects to ``died``; every component on the character also hears it as the ``died`` event, and whoever dealt the killing blow hears ``killed``. ``revive()`` sends ``revived``.

For a shield that takes damage before health does, add a :ref:`Pool<class_Pool>` with Absorbs Damage on; see :ref:`doc_pools`.

Health stays full until the manager sends ``started``, the moment every component has had its chance to start. Innate passives such as "+20 max health" are applied by then, so a character starts at its buffed maximum whatever the node order. After that, raising the maximum doesn't heal.

.. _doc_brain_the_only_difference_between_a_player_and_an_ai:

Brain: the only difference between a player and an AI
-----------------------------------------------------

A :ref:`Brain<class_Brain>` publishes intent and nothing else. Every other component reads intent from the :ref:`Brain<class_Brain>` and never asks where it came from. Components read its buttons the way Godot's input docs read the :ref:`Input<class_Input>` singleton, polling in ``_process()`` or ``_physics_process()``: ``brain.is_action_just_pressed(&"jump")`` for a one-off action, and ``brain.is_action_pressed(&"primary")`` for one that lasts while it's held.

.. source-file:: ../../character_system/character/brains/brain.gd

.. source-file:: ../../character_system/character/brains/player_brain.gd

Input actions are created in Project > Project Settings > Input Map. Leave Camera empty and :ref:`PlayerBrain<class_PlayerBrain>` uses the first ``Camera3D`` under the character, as :ref:`MouseLook<class_MouseLook>` does.

:ref:`PlayerBrain<class_PlayerBrain>` takes presses from input events in ``_unhandled_input()``, so a click the UI uses never reaches the character. It polls releases every frame with ``Input.is_action_pressed()``, so a button let go while the game was paused, over the UI or in another window doesn't stay held, and an action bound to two keys stays held until both are up. AI and tests press buttons with ``press()`` and ``release()``. A press made from code counts from the next frame, so every node sees it exactly once wherever in the frame it was made; presses from input events count straight away, as they do in :ref:`Input<class_Input>`.

**Aiming.** A :ref:`PlayerBrain<class_PlayerBrain>`'s ``aim_point`` is the first thing a ray from the camera meets, up to 100 metres away: the point under the crosshair. Weapons and thrown projectiles start where they are and go toward that point, so a gun held low at the hip hits what the crosshair is on at any range, and a wall between the gun and the target stops the shot, as it should. Three details keep that honest: the character's own body and hurtboxes are ignored; the ray starts level with the character, so a camera behind it can't aim at something in between; and the point is never closer than 1.5 metres, so a shot at a wall in the player's face doesn't turn round. Like a shot, the ray passes through areas that aren't hurtboxes and through dead characters, so the crosshair never rests on something a bullet would ignore. Untick layers in **Aim Mask** to aim through them as well.

.. source-file:: ../../character_system/character/brains/ai_brain.gd

Because AI presses the same "buttons" as the player, with ``press()`` and ``release()``, every weapon and ability works for AI with no extra code.

.. _doc_stuns:

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

Leave Agent empty and :ref:`AIBrain<class_AIBrain>` uses the first ``NavigationAgent3D`` under the character. Finding a path is the expensive part of steering, so a new one is only asked for once the target has moved ``repath_distance`` metres (1 by default). In a test with 50 enemies chasing a running player, asking every physics frame cost about seven times as much frame time. Lower the distance for a target that moves fast and turns sharply.

Motor
-----

The :ref:`CharacterMotor<class_CharacterMotor>` moves the character through movement modes and layered moves, which are nodes under it rather than components. It has a page of its own: :ref:`doc_movement`.

.. _doc_mouse_look:

Mouse look
----------

.. source-file:: ../../character_system/character/brains/mouse_look.gd

The click that recaptures the mouse is only swallowed if the capture worked, so on platforms that refuse it (a headless run, some browsers) clicks still reach the weapon.

.. _doc_faction:

Faction
-------

.. source-file:: ../../character_system/character/combat/faction.gd

AI target selection filters candidates with ``is_hostile``. While :ref:`Faction<class_Faction>` runs, the character is also in the Godot group named after its team, so ``get_tree().get_nodes_in_group(&"enemy")`` lists every enemy. Changing sides at runtime (charm, betrayal) is a change to ``team``, which moves the character to the new group, and to ``hostile_to``.

.. _doc_items_and_inventory:

Items and inventory
-------------------

Items have two parts. :ref:`ItemData<class_ItemData>` is the shared definition ("what a rifle is") and never changes while playing. :ref:`ItemInstance<class_ItemInstance>` is one copy ("this rifle, with 4 rounds loaded"). Stackable items such as ammo share one instance per stack.

.. source-file:: ../../character_system/character/items/item_data.gd

.. source-file:: ../../character_system/character/items/item_instance.gd

.. source-file:: ../../character_system/character/items/inventory.gd

``items.duplicate()`` loops over a copy, because removing from an array while looping over it skips entries. Every change emits ``changed`` and also sends the ``inventory_changed`` event, which :ref:`Equipment<class_Equipment>` uses to unequip what was dropped and :ref:`WeaponSwitch<class_WeaponSwitch>` uses to draw a weapon. ``first()`` finds a stack, and ``remove_instance()`` drops one particular copy and keeps its state. Since :ref:`ItemInstance<class_ItemInstance>` is a :ref:`Resource<class_Resource>`, a whole inventory can be saved with ``ResourceSaver.save()``.

**Consumables.** An item with ``use_effects`` can be used: ``Inventory.use(data)`` runs them on the character and takes one from the stack, unless the item's ``consumed_on_use`` is off. A health potion is an :ref:`ItemData<class_ItemData>` with a :ref:`HealEffect<class_HealEffect>` and no scene; ``starter_pack/items/health_potion.tres`` is one.

.. _doc_abilities:

Abilities
---------

An ability is data: when it can be used, what it costs, who it targets and which effects it runs. :ref:`Effect<class_Effect>` and :ref:`EffectContext<class_EffectContext>` are explained in :ref:`doc_effects`.

.. source-file:: ../../character_system/character/abilities/targeting.gd

.. source-file:: ../../character_system/character/abilities/ability_data.gd

.. source-file:: ../../character_system/character/abilities/abilities.gd

Only ``effects`` is needed; everything else is switched on by filling it in.

.. list-table::
   :header-rows: 1

   * - Field
     - Gives you
     - Example
   * - ``cooldown``, ``charges``
     - A wait between uses, and several uses banked
     - A dash with two charges that come back one at a time
   * - ``costs``
     - A price taken from the user's :ref:`Pool<class_Pool>`\ s
     - 20 mana
   * - ``conditions``
     - Rules for when it can be used, checked on the user
     - A last-stand heal that needs health below a quarter
   * - ``blocked_by``
     - The names it answers to; a status that blocks one stops it
     - ``abilities``, and ``spells`` for the ones Silenced should stop
   * - ``cast_time``, ``status_while_casting``, ``interrupted_by_damage``
     - A wind-up that can be cut short
     - Half a second, slowed while casting, broken by a hit
   * - ``targeting``, ``needs_target``
     - Who the effects reach, and whether it can be used on nobody
     - Everyone within 5 metres, and only if someone is
   * - ``effects``, ``user_effects``
     - What happens to the targets, and to the user
     - Damage to enemies nearby, and a heal for the caster

``use()`` asks ``why_not()`` first, which names the first thing against the ability: ``blocked`` (a status is blocking the brain or the ability), ``casting``, ``cooldown``, ``cost``, ``condition`` or ``no_target``. If there is one, nothing happens except the ``failed`` signal, which carries the reason for a "Not enough mana" message; ``can_use()`` answers the same question for a greyed-out button.

**Costs are paid when the effects run.** An ability with a cast time checks that it can be paid for when the cast starts, and takes the costs and the charge when it ends. A cast that is interrupted, by a stun, a blocking status, damage or your own call to ``interrupt()``, costs nothing and starts no cooldown. Only one ability is cast at a time.

**Cooldowns run on game time.** They are counted in ``_process()``, so they stop while the game is paused and follow ``Engine.time_scale``, and they're scaled by the ``cooldown_speed`` stat, so a status or an item can speed them up. ``cooldown_left()`` gives the seconds until the ability can be used again, ``charges_left()`` and ``recharge_left()`` describe its charges, and ``cast_progress()`` drives a cast bar. A slot fires on ``is_action_just_pressed()``, so holding the button uses the ability once.

Left empty, an ability's ``targeting`` affects the user. :ref:`RadiusTargeting<class_RadiusTargeting>` reaches everything within a radius, for a shockwave (``starter_pack/abilities/shockwave.tres``, which also has two charges) or a healing aura, and :ref:`doc_extending_targeting` shows how to write your own. An ability that throws something puts a :ref:`LaunchProjectileEffect<class_LaunchProjectileEffect>` in ``user_effects``; ``starter_pack/abilities/fireball.tres`` does, with a mana cost and a cast time.

Statuses can react to abilities: ``ability_cast_started``, ``ability_used`` and ``ability_interrupted`` are events like any other, with the ability as the context's ``origin``. Items can grant abilities while equipped with :ref:`Grants<class_Grants>`.

Passive abilities are not handled here. A passive is a status with no duration, given by ``Statuses.innate``, an item or a zone. Not sure whether an idea should be an ability, a status or a component? See :ref:`doc_ability_status_or_component`.
