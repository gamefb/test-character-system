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
   * - :ref:`Health<class_Health>`
     - Current health, death, ``max_health`` and resistances
     - none
     - none
     - ``changed``, ``died``
   * - :ref:`Brain<class_Brain>`
     - Intent: move direction, aim point, held and just-pressed buttons
     - none
     - none
     - none
   * - :ref:`Movement<class_Movement>`
     - Turning intent into motion, ``move_speed``, ``jump_velocity``, pushes
     - :ref:`Brain<class_Brain>`
     - none
     - none
   * - :ref:`DoubleJump<class_DoubleJump>`
     - Jumps in the air, ``air_jumps``
     - Brain, Movement
     - none
     - none
   * - :ref:`MouseLook<class_MouseLook>`
     - Turning the player and its camera with the mouse; capturing the mouse
     - none (set its Camera)
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
     - Ability slots and cooldowns
     - :ref:`Brain<class_Brain>`
     - none
     - none
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

.. source-file:: ../../character_system/characters/components/health.gd

What death means (ragdoll, loot drop, game over) is decided by whatever connects to ``died``; every component on the character also hears it as the ``died`` event. ``revive()`` brings the character back.

Health stays full until the manager sends ``started``, the moment every component has had its chance to start. Innate passives such as "+20 max health" are applied by then, so a character starts at its buffed maximum whatever the node order. After that, raising the maximum doesn't heal.

.. _doc_brain_the_only_difference_between_a_player_and_an_ai:

Brain: the only difference between a player and an AI
-----------------------------------------------------

A :ref:`Brain<class_Brain>` publishes intent and nothing else. Every other component reads intent from the :ref:`Brain<class_Brain>` and never asks where it came from. Components read its buttons the way Godot's input docs read the :ref:`Input<class_Input>` singleton, polling in ``_process()`` or ``_physics_process()``: ``brain.is_action_just_pressed(&"jump")`` for a one-off action, and ``brain.is_action_pressed(&"primary")`` for one that lasts while it's held.

.. source-file:: ../../character_system/characters/brains/_base/brain.gd

.. source-file:: ../../character_system/characters/brains/player_brain.gd

Input actions are created in Project > Project Settings > Input Map.

:ref:`PlayerBrain<class_PlayerBrain>` takes presses from input events in ``_unhandled_input()``, so a click the UI uses never reaches the character. It polls releases every frame with ``Input.is_action_pressed()``, so a button let go while the game was paused, over the UI or in another window doesn't stay held, and an action bound to two keys stays held until both are up. AI and tests press buttons with ``press()`` and ``release()``. A press made from code counts from the next frame, so every node sees it exactly once wherever in the frame it was made; presses from input events count straight away, as they do in :ref:`Input<class_Input>`.

.. source-file:: ../../character_system/characters/brains/ai_brain.gd

Because AI presses the same "buttons" as the player, with ``press()`` and ``release()``, every weapon and ability works for AI with no extra code.

.. _doc_movement:

Movement
--------

.. source-file:: ../../character_system/characters/components/movement.gd

Speed is read through ``stat()`` every frame, so a slow status or a speed ring takes effect immediately. ``push()`` is how effects shove a character: :ref:`KnockbackEffect<class_KnockbackEffect>` uses it, and a dash ability could too. A flying or swimming character swaps this component for another that reads the same :ref:`Brain<class_Brain>`.

.. _doc_double_jump:

Double jump
-----------

.. source-file:: ../../character_system/characters/components/double_jump.gd

A double jump is its own component, so a character only has one if you add it. Pressing ``jump`` in the air jumps as high as a jump from the floor, and the air jumps come back on landing. How many there are is the ``air_jumps`` stat, so it works like any other number in the system: a status adding 1 makes a triple jump, boots can grant the jump through a status, and a rooted status can multiply it by 0. To give the jump only through an item, add the component with :ref:`air_jumps<class_DoubleJump_property_air_jumps>` at 0 and let the item's status add to it.

The press that starts a jump from the floor must not also use up an air jump. :ref:`Movement<class_Movement>` and :ref:`DoubleJump<class_DoubleJump>` both read the same press in the same physics frame, in either order, so :ref:`Movement<class_Movement>` records the frame it jumped and :ref:`DoubleJump<class_DoubleJump>` checks :ref:`jumped_this_frame()<class_Movement_method_jumped_this_frame>` before using an air jump.

.. _doc_mouse_look:

Mouse look
----------

.. source-file:: ../../character_system/characters/components/mouse_look.gd

The click that recaptures the mouse is only swallowed if the capture worked, so on platforms that refuse it (a headless run, some browsers) clicks still reach the weapon.

.. _doc_faction:

Faction
-------

.. source-file:: ../../character_system/characters/components/faction.gd

AI target selection filters candidates with ``is_hostile``. While :ref:`Faction<class_Faction>` runs, the character is also in the Godot group named after its team, so ``get_tree().get_nodes_in_group(&"enemy")`` lists every enemy. Changing sides at runtime (charm, betrayal) is a change to ``team``, which moves the character to the new group, and to ``hostile_to``.

.. _doc_items_and_inventory:

Items and inventory
-------------------

Items have two parts. :ref:`ItemData<class_ItemData>` is the shared definition ("what a rifle is") and never changes while playing. :ref:`ItemInstance<class_ItemInstance>` is one copy ("this rifle, with 4 rounds loaded"). Stackable items such as ammo share one instance per stack.

.. source-file:: ../../character_system/resources/items/item_data.gd

.. source-file:: ../../character_system/resources/items/item_instance.gd

.. source-file:: ../../character_system/characters/components/inventory.gd

``items.duplicate()`` loops over a copy, because removing from an array while looping over it skips entries. Every change emits ``changed`` and also sends the ``inventory_changed`` event, which :ref:`Equipment<class_Equipment>` uses to unequip what was dropped and :ref:`WeaponSwitch<class_WeaponSwitch>` uses to draw a weapon. ``first()`` finds a stack, and ``remove_instance()`` drops one particular copy and keeps its state. Since :ref:`ItemInstance<class_ItemInstance>` is a :ref:`Resource<class_Resource>`, a whole inventory can be saved with ``ResourceSaver.save()``.

.. _doc_abilities:

Abilities
---------

An ability is data: who it targets and which effects it runs. :ref:`Effect<class_Effect>` and :ref:`EffectContext<class_EffectContext>` are defined under Effects, statuses and passives.

.. source-file:: ../../character_system/resources/abilities/targeting/_base/targeting.gd

.. source-file:: ../../character_system/resources/abilities/ability_data.gd

.. source-file:: ../../character_system/characters/components/abilities.gd

Cooldowns run on game time. Each one is a :ref:`SceneTreeTimer<class_SceneTreeTimer>`, so it stops while the game is paused and follows ``Engine.time_scale``. ``cooldown_left()`` gives the seconds left, for an ability bar. A slot fires on ``is_action_just_pressed()``, so holding the button uses the ability once.

Passive abilities are not handled here. A passive is a status with no duration, given by ``Statuses.innate``, an item or a zone.

.. _doc_ability_status_or_component:

Ability, status or component?
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

New gameplay usually fits one of three places:

- An **ability** is one action that happens once per press, then cools down.
- A **status** changes numbers and reacts to events, for a while or as long as something holds
  it.
- A **component** is ongoing behaviour with its own memory, running every frame.

To place a new idea, ask in this order:

1. Does it happen once per press, then cool down? Make it an **ability**.
2. Does it change a number, or react to hits or deaths, for a while or while equipped? Make it a
   **status**, which an ability, item or zone can apply.
3. Does it need memory between frames or presses, a held button, or a change to how the
   character moves or acts? Make it a **component**.

.. list-table::
   :header-rows: 1
   :widths: 20 40 40

   * -
     - Good at
     - Limits
   * - Ability
     - One-off actions such as a heal, a fireball, a dash or applying a buff. Built in the
       Inspector with no code when the effects exist. Granted or removed during play by
       changing ``slots``; AI calls ``use()``.
     - Fires only on a fresh press: nothing while held, on release, charged or channelled. A
       cooldown is its only cost: no charges, mana, cast time or interruption. Effects are
       instant, so anything lasting goes through a status. It remembers nothing between uses
       but its cooldown. Conditions sit on the effects, so a failed one skips its effect but
       still spends the cooldown.
   * - Status
     - Stat changes, reactions to events (shields, thorns, burning), immunities and passives.
       Built in the Inspector. Timed, stacked, or held by items and zones.
     - Can't read buttons or run every frame, except ticks at ``tick_interval``. Only changes
       numbers some component already owns.
   * - Component
     - Anything that runs every frame, remembers state, reads held buttons, owns stats that
       statuses can change, or needs other components.
     - Needs GDScript and the start and stop lifecycle. Added to each character's scene, so
       designers can't mix and match them as freely as resources. No built-in cooldowns or
       costs.

Some examples:

.. list-table::
   :header-rows: 1
   :widths: 30 20 50

   * - Idea
     - Where
     - Why
   * - Double jump
     - Component
     - Remembers jumps left, checks the floor every frame and shares the jump button with
       :ref:`Movement<class_Movement>`. See :ref:`doc_double_jump`.
   * - Learning to double jump, or boots that grant it
     - Status
     - Adds 1 to the ``air_jumps`` stat that :ref:`DoubleJump<class_DoubleJump>` owns.
   * - Dash
     - Ability
     - Once per press: a :ref:`KnockbackEffect<class_KnockbackEffect>` on the user, then a
       cooldown.
   * - Sprint
     - Ability
     - Once per press: applies a speed status (``examples/abilities/sprint.tres`` applies
       Haste).
   * - Hover while holding jump
     - Component
     - Runs every frame while a button is held.

When new behaviour needs code, prefer a new :ref:`Effect<class_Effect>` over a new component
where you can: one effect works in abilities, statuses, weapons and zones at once.

Most of the grey area comes from the ability limits above. A spell with charges, a mana cost or
a charge-up can't be an ability yet, so today it would be a component of its own.
