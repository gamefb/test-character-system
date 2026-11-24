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

The motor has no modes or moves of its own. The ones named here are in the starter pack, and :ref:`doc_example_movements` covers each of them; yours go in the same place.

Modes and moves are plain nodes under the motor, not components, so they don't need a :ref:`ComponentManager<class_ComponentManager>` of their own. A mode or move anywhere else shows a warning in the Scene dock.

.. _doc_movement_each_frame:

What happens each frame
-----------------------

Every physics frame, the motor:

1. lets the current mode set the body's velocity, e.g. WalkMode sets it from the brain's ``move_dir`` and the ``move_speed`` stat,
2. lets each layered move start, then change the velocity while it runs, in the order they are in the scene,
3. calls ``move_and_slide()``, the only place in the system that does,
4. asks the mode whether to hand over to another, e.g. WalkMode hands over to AirMode once the floor is gone. If it doesn't, any other mode may take over by itself.

.. source-file:: ../../character_system/character/motor/character_motor.gd

Three rules keep features from getting in each other's way:

- **Only the current mode runs.** WalkMode and AirMode both jump, but never in the same frame, so their code doesn't need to know about each other.
- **A press is used once.** Modes and moves read held buttons and ``move_dir`` from ``motor.brain``, but presses that only one of them should act on go through ``motor.consume_action(&"jump")``. It's true for the first caller in the frame of the press and false after that. So the press that jumps from the floor can't also use up an air jump, and a dash and a jump bound to the same button can't both happen. :ref:`Abilities<class_Abilities>` read presses straight from the brain instead, so don't put an ability on an action a mode or move uses: both would fire.
- **Velocity is set, then the body moves once.** Every mode and move changes ``body.velocity`` and none calls ``move_and_slide()``, so what a dash does on top of walking is just a line of code, not a race between two nodes.

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

.. _doc_movement_statuses_events_cooldowns:

Statuses, events and cooldowns
------------------------------

Every mode and move gets these from its base class, so one you write yourself has them too.

**Statuses that stop movement.** A status changes how fast the character moves through stats: Wet multiplies ``move_speed``, which every built-in mode reads. To stop movement outright, a status lists ``movement`` in its **Blocks**, as the example :ref:`Rooted<doc_example_statuses>` does. The motor answers to that name (its **Blocked By**), and while it is blocked:

- ``motor.move_dir``, which modes steer by, reads as zero, and ``consume_action()`` refuses presses, so there is no walking and no jumping;
- a move can't start, and one already running ends;
- gravity, friction and pushes still apply, so a rooted character falls and can be knocked back.

A single mode or move can answer to a name of its own as well. Give a glide ``flight`` in its **Blocked By**, and a status that blocks ``flight`` stops gliding and nothing else: the move can't start, or the mode hands back to the motor's start mode. Don't block the start mode: it's where a blocked mode goes back to.

A stun needs none of this to stop walking, jumping or starting a dash: a status that blocks ``everything`` makes the :ref:`Brain<class_Brain>` report no intent, and every mode and move reads the brain. Let it block ``movement`` as well to cut short a move that is already under way, such as a dash in mid-air.

**Events.** The motor sends an :ref:`event<doc_events>` to the character's components and statuses each time a mode takes over or hands over, and each time a move starts or finishes. The name is the class name in snake_case, then what happened:

.. list-table::
   :header-rows: 1

   * - Event
     - When
   * - ``walk_mode_entered``
     - Landing
   * - ``air_mode_entered``
     - Jumping, or walking off a ledge
   * - ``walk_mode_exited``, ``air_mode_exited``
     - The mode hands over
   * - ``dash_move_started``, ``dash_move_finished``
     - A dash starts and ends

Your own modes and moves send theirs the same way, e.g. ``wall_slide_mode_entered``. The mode the motor starts in sends nothing, so a character doesn't "land" when it spawns. A status trigger on ``walk_mode_entered`` makes a landing shockwave; one on ``dash_move_started`` can make dashing cost health. In code, ``mode_changed`` and a move's ``started`` and ``finished`` signals say the same.

**Cooldowns.** Every layered move has a **Cooldown**: the time from the start of one run until the next may start, in game time, so it stops while the game is paused, as an ability's cooldown does. While it counts down the move isn't asked to start, so its press is left for something else, and ``cooldown_left()`` tells a HUD how long is left. DashMove's is 0.6 seconds.

.. _doc_movement_base_classes:

The base classes
----------------

:ref:`MotorNode<class_MotorNode>` is what modes and moves share: ``motor``, ``body``, ``stat()``, stats of their own, and the ``_enter()``, ``_exit()`` and ``_physics_update()`` hooks. Extend :ref:`MovementMode<class_MovementMode>` or :ref:`LayeredMove<class_LayeredMove>` rather than this.

.. source-file:: ../../character_system/character/motor/motor_node.gd

.. source-file:: ../../character_system/character/motor/movement_mode.gd

.. source-file:: ../../character_system/character/motor/layered_move.gd
