.. _doc_example_movements:

Movement
========

How a character gets around. The framework's :ref:`CharacterMotor<class_CharacterMotor>` runs modes and moves but has none of its own (see :ref:`doc_movement`). These are the ones in the starter pack, in ``character_system/starter_pack/scripts/``. Add the ones a character should have as children of its motor.

.. list-table::
   :header-rows: 1

   * - Node
     - Kind
     - What the player gets
   * - :ref:`WalkMode<class_WalkMode>`
     - Mode
     - Walking at the ``move_speed`` stat, and jumping from the floor
   * - :ref:`AirMode<class_AirMode>`
     - Mode
     - Falling, steering in the air, and jumping again while ``air_jumps`` are left
   * - :ref:`DashMove<class_DashMove>`
     - Move
     - A short burst the way the character is moving, with a cooldown
   * - :ref:`GlideMove<class_GlideMove>`
     - Move
     - Holding jump while falling to come down slowly
   * - :ref:`WallSlideMode<class_WallSlideMode>`
     - Mode
     - Sliding slowly down a wall, and jumping off it

A mode is how the character moves right now, and only one runs at a time. A move runs on top of whichever mode is active. GlideMove and WallSlideMode are also the worked examples in :ref:`doc_extending_movement`, which walks through writing your own.

.. _doc_movement_walk_and_air:

Walking, falling and double jumps
---------------------------------

.. source-file:: ../../character_system/starter_pack/scripts/walk_mode.gd

.. source-file:: ../../character_system/starter_pack/scripts/air_mode.gd

WalkMode and AirMode are written like Godot's own CharacterBody3D script template: gravity from ``get_gravity()``, so gravity zones work, ``velocity.x`` and ``velocity.z`` from the direction, and ``velocity.y`` for jumps. AirMode steers with ``move_toward()``, so the character keeps some of its speed in the air; lower ``air_acceleration`` keeps more.

Air jumps come back every time the character takes off. How many there are is AirMode's ``air_jumps`` stat, so it works like any other number in the system: a status adding 1 makes a triple jump, boots can grant the jump through a status. To give the jump only through an item, set :ref:`air_jumps<class_AirMode_property_air_jumps>` to 0 and let the item's status add to it. ``jumps_left`` is there for a HUD.

Each mode hands over to the other: WalkMode to its ``air_mode`` and AirMode to its ``walk_mode``. Left empty, those are the AirMode and WalkMode beside them, so a character with just the two needs no setup. Point them at your own modes to change the flow, e.g. AirMode's ``walk_mode`` at a heavy landing mode.

.. _doc_movement_dash:

Dashing
-------

.. source-file:: ../../character_system/starter_pack/scripts/dash_move.gd

DashMove replaces the velocity while it runs, so it works the same on the floor and in the air, ignores gravity, and can't be steered. Its cooldown is the Cooldown every layered move has (see :ref:`doc_movement_statuses_events_cooldowns`). Afterwards the mode takes over again: walking stops at once, while the air keeps some of the speed. Add a ``dash`` action to the Input Map and to the :ref:`PlayerBrain<class_PlayerBrain>`'s Extra Actions, as for any action of your own.

A dash can also be an :ref:`ability<doc_abilities>` with a :ref:`KnockbackEffect<class_KnockbackEffect>` on the user. That's a one-off shove with a cooldown, built in the Inspector. DashMove is for a dash that controls the character for its whole length.
