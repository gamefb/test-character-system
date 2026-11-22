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

Input actions are created in Project > Project Settings > Input Map. Leave Camera empty and :ref:`PlayerBrain<class_PlayerBrain>` uses the first ``Camera3D`` under the character, as :ref:`MouseLook<class_MouseLook>` does.

:ref:`PlayerBrain<class_PlayerBrain>` takes presses from input events in ``_unhandled_input()``, so a click the UI uses never reaches the character. It polls releases every frame with ``Input.is_action_pressed()``, so a button let go while the game was paused, over the UI or in another window doesn't stay held, and an action bound to two keys stays held until both are up. AI and tests press buttons with ``press()`` and ``release()``. A press made from code counts from the next frame, so every node sees it exactly once wherever in the frame it was made; presses from input events count straight away, as they do in :ref:`Input<class_Input>`.

.. source-file:: ../../character_system/characters/brains/ai_brain.gd

Because AI presses the same "buttons" as the player, with ``press()`` and ``release()``, every weapon and ability works for AI with no extra code.

Leave Agent empty and :ref:`AIBrain<class_AIBrain>` uses the first ``NavigationAgent3D`` under the character. Finding a path is the expensive part of steering, so a new one is only asked for once the target has moved ``repath_distance`` metres (1 by default). In a test with 50 enemies chasing a running player, asking every physics frame cost about seven times as much frame time. Lower the distance for a target that moves fast and turns sharply.

Motor
-----

The :ref:`CharacterMotor<class_CharacterMotor>` moves the character through movement modes and layered moves, which are nodes under it rather than components. It has a page of its own: :ref:`doc_movement`.

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

An ability is data: who it targets and which effects it runs. :ref:`Effect<class_Effect>` and :ref:`EffectContext<class_EffectContext>` are explained in :ref:`doc_effects`.

.. source-file:: ../../character_system/resources/abilities/targeting/_base/targeting.gd

.. source-file:: ../../character_system/resources/abilities/ability_data.gd

.. source-file:: ../../character_system/characters/components/abilities.gd

Cooldowns run on game time. Each one is a :ref:`SceneTreeTimer<class_SceneTreeTimer>`, so it stops while the game is paused and follows ``Engine.time_scale``. ``cooldown_left()`` gives the seconds left, for an ability bar. A slot fires on ``is_action_just_pressed()``, so holding the button uses the ability once.

Left empty, an ability's ``targeting`` affects the user. :ref:`RadiusTargeting<class_RadiusTargeting>` reaches everything within a radius, for a shockwave or a healing aura, and :ref:`doc_extending_targeting` shows how to write your own.

Passive abilities are not handled here. A passive is a status with no duration, given by ``Statuses.innate``, an item or a zone. Not sure whether an idea should be an ability, a status or a component? See :ref:`doc_ability_status_or_component`.
