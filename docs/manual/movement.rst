.. _doc_movement:

Movement
========

A :ref:`CharacterMotor<class_CharacterMotor>` moves the character. It works like a state machine: its children are the ways the character can move, and it runs one of them at a time.

.. code:: text

   Player (CharacterBody3D)
   ├── ComponentManager
   ├── PlayerBrain
   └── CharacterMotor   <- a component, beside the others
       ├── WalkMode     <- movement modes: one is in charge at a time
       ├── AirMode
       └── DashMove     <- layered moves: run on top of the mode for a while

- A **movement mode** (:ref:`MovementMode<class_MovementMode>`) is one way of moving, such as walking, falling, swimming or climbing. Exactly one is in charge, the motor's ``mode``. :ref:`WalkMode<class_WalkMode>` walks and jumps; :ref:`AirMode<class_AirMode>` falls, steers and jumps again in the air.
- A **layered move** (:ref:`LayeredMove<class_LayeredMove>`) is extra movement for a while, on top of whichever mode is in charge, such as :ref:`DashMove<class_DashMove>`. Several can run at once.

Modes and moves are plain nodes under the motor, not components, so they don't need a :ref:`ComponentManager<class_ComponentManager>` of their own. A mode or move anywhere else shows a warning in the Scene dock.

.. _doc_movement_each_frame:

What happens each frame
-----------------------

Every physics frame, the motor:

1. lets the current mode set the body's velocity, e.g. WalkMode sets it from the brain's ``move_dir`` and the ``move_speed`` stat,
2. lets each layered move start, then change the velocity while it runs, in the order they are in the scene,
3. calls ``move_and_slide()``, the only place in the system that does,
4. asks the mode whether to hand over to another, e.g. WalkMode hands over to AirMode once the floor is gone. If it doesn't, any other mode may take over by itself.

.. source-file:: ../../character_system/characters/motor/character_motor.gd

Three rules keep features from getting in each other's way:

- **Only the current mode runs.** WalkMode and AirMode both jump, but never in the same frame, so their code doesn't need to know about each other.
- **A press is used once.** Modes and moves read held buttons and ``move_dir`` from ``motor.brain``, but presses that only one of them should act on go through ``motor.consume_action(&"jump")``. It's true for the first caller in the frame of the press and false after that. So the press that jumps from the floor can't also use up an air jump, and a dash and a jump bound to the same button can't both happen.
- **Velocity is set, then the body moves once.** Every mode and move changes ``body.velocity`` and none calls ``move_and_slide()``, so what a dash does on top of walking is just a line of code, not a race between two nodes.

.. _doc_movement_walk_and_air:

Walking, falling and double jumps
---------------------------------

.. source-file:: ../../character_system/characters/motor/walk_mode.gd

.. source-file:: ../../character_system/characters/motor/air_mode.gd

WalkMode and AirMode are written like Godot's own CharacterBody3D script template: gravity from ``get_gravity()``, so gravity zones work, ``velocity.x`` and ``velocity.z`` from the direction, and ``velocity.y`` for jumps. AirMode steers with ``move_toward()``, so the character keeps some of its speed in the air; lower ``air_acceleration`` keeps more.

Air jumps come back every time the character takes off. How many there are is AirMode's ``air_jumps`` stat, so it works like any other number in the system: a status adding 1 makes a triple jump, boots can grant the jump through a status, and a rooted status can multiply it by 0. To give the jump only through an item, set :ref:`air_jumps<class_AirMode_property_air_jumps>` to 0 and let the item's status add to it. ``jumps_left`` is there for a HUD.

Each mode hands over to the other: WalkMode to its ``air_mode`` and AirMode to its ``walk_mode``. Left empty, those are the AirMode and WalkMode beside them, so a character with just the two needs no setup. Point them at your own modes to change the flow, e.g. AirMode's ``walk_mode`` at a heavy landing mode.

.. _doc_movement_dash:

Dashing
-------

.. source-file:: ../../character_system/characters/motor/dash_move.gd

DashMove replaces the velocity while it runs, so it works the same on the floor and in the air, ignores gravity, and can't be steered. Afterwards the mode takes over again: walking stops at once, while the air keeps some of the speed. Add a ``dash`` action to the Input Map and to the :ref:`PlayerBrain<class_PlayerBrain>`'s Extra Actions, as for any action of your own.

A dash can also be an :ref:`ability<doc_abilities>` with a :ref:`KnockbackEffect<class_KnockbackEffect>` on the user. That's a one-off shove with a cooldown, built in the Inspector. DashMove is for a dash that controls the character for its whole length.

.. _doc_movement_from_code:

Using the motor from your own code
----------------------------------

- **Switch modes** by setting ``motor.mode``, e.g. ``motor.mode = $CharacterMotor/ClimbMode`` when a ladder is grabbed. Only a mode that is a child of the motor is accepted. ``motor.get_mode(AirMode)`` finds a mode by type, and ``motor.mode is AirMode`` checks which one is in charge.
- **React to modes** with the ``mode_changed`` signal, e.g. to play a landing animation when the new mode is a WalkMode.
- **Start or end a move** by setting its ``active``, e.g. a jump pad that sets ``boost.active = true``. Its ``started`` and ``finished`` signals are for sounds and effects.
- **Shove the character** with ``motor.push(velocity)``. :ref:`KnockbackEffect<class_KnockbackEffect>` uses it. The upward part applies at once and the sideways part wears off at ``push_friction``.
- **Change speeds** with statuses, through the ``move_speed`` and ``jump_velocity`` stats the motor owns, and any stats its modes and moves own, such as ``air_jumps``.
- **Change keys** in the Input Map, as in any Godot game. To make a mode or move use another action, set its ``jump_action`` or ``action`` in the Inspector.

To add a new way of moving, see :ref:`doc_extending_movement`.

.. _doc_movement_base_classes:

The base classes
----------------

:ref:`MotorNode<class_MotorNode>` is what modes and moves share: ``motor``, ``body``, ``stat()``, stats of their own, and the ``_enter()``, ``_exit()`` and ``_physics_update()`` hooks. Extend :ref:`MovementMode<class_MovementMode>` or :ref:`LayeredMove<class_LayeredMove>` rather than this.

.. source-file:: ../../character_system/characters/motor/_base/motor_node.gd

.. source-file:: ../../character_system/characters/motor/_base/movement_mode.gd

.. source-file:: ../../character_system/characters/motor/_base/layered_move.gd
