.. _doc_build_from_scratch:

Build it from scratch
=====================

This guide walks you through building the system yourself, so you understand every part before
you rely on it. There are six stages. Each one ends with something you can run, and uses only
classes from the stages before it.

.. graphviz::
   :caption: Build order. Items and abilities both sit on statuses and effects.

   digraph build_order {
       rankdir=LR;
       node [shape=box, style="rounded,filled", fillcolor="#e8f1fa", color="#3d8fcc"];
       edge [color="#7a7a7a"];
       core [label="1. Core"];
       first [label="2. First components"];
       effects [label="3. Effects and conditions"];
       statuses [label="4. Statuses"];
       items [label="5. Items"];
       abilities [label="6. Abilities"];
       core -> first -> effects -> statuses;
       statuses -> items;
       statuses -> abilities;
   }

Stage 1 is the hub everything else plugs into. Items and abilities both sit on statuses and
effects, so build them last, in either order.

Every class below is described the same way:

- **What it is**: one line on its job, and the Godot type it extends.
- **Members**: the variables, signals and functions you need to write, as a table. Names match
  the reference project, so you can compare your version with it when you get stuck. The
  :ref:`class reference <doc_class_reference>` has the full documentation of each one.
- **Watch out for**: the parts that needed fixing in the reference build.
- **Test**: what to check before moving on.

Where a function is marked *virtual*, the base class leaves it empty and subclasses override
it. Signatures use GDScript 2 syntax, and the code uses typed dictionaries, so you need
Godot 4.4 or later. Write the scripts in the style of the
`GDScript style guide <https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html>`__:
``class_name`` and ``extends`` on their own lines, then signals, enums, constants, exports,
variables, and functions, with static types wherever the type isn't obvious.

Stage 1: The core
-----------------

Five classes, no gameplay yet. When this stage works, components find each other, wait for what
they need, and share stats and events through one hub per character.

EffectContext
~~~~~~~~~~~~~

**What it is:** a ``RefCounted`` that says who did what to whom. Every effect, condition and
event receives one.

.. list-table::
   :header-rows: 1
   :widths: 25 20 55

   * - Member
     - Type
     - Purpose
   * - ``source``
     - ``Node``
     - Who caused it. Null for the environment.
   * - ``target``
     - ``Node``
     - Who receives it.
   * - ``origin``
     - ``Resource``
     - What caused it: the StatusData, AbilityData and so on.
   * - ``magnitude``
     - ``float = 1.0``
     - A multiplier: headshot ×2, status stacks.
   * - ``amount``
     - ``float = 0.0``
     - The damage or healing being worked out; afterwards, what landed.
   * - ``add``, ``percent``, ``mul``
     - ``float`` (0, 0, 1)
     - Running totals that statuses and components change before the number lands.
   * - ``damage_type``
     - ``StringName``
     - The kind of damage, e.g. ``fire``. Set by ``DamageEffect``.
   * - ``tags``
     - ``Array[StringName]``
     - Labels on the hit: ``head`` from a hurtbox, ``melee`` from the effect, ``crit``.
   * - ``position``, ``normal``
     - ``Vector3``
     - Where the hit landed, if a ray recorded it. ``position`` is ``Vector3.INF`` if not.
   * - ``from_status``
     - ``bool = false``
     - True when a status started this. Stops statuses from setting each other off forever.
   * - ``cause``
     - ``EffectContext``
     - Inside a status trigger, the context of the event that set it off, e.g. the hit a
       shield is reducing.
   * - ``depth``
     - ``int = 0``
     - How many triggers led here. A chain is cut at ``MAX_DEPTH``.
   * - ``_init(source, target, origin)``
     - constructor
     - All three optional.
   * - ``hit()``
     - func
     - ``cause`` if there is one, else itself: the hit a condition should judge.
   * - ``resolve()``
     - func
     - ``(amount + add) × (1 + percent) × mul``, never below 0.
   * - ``reset_amount(value)``
     - func
     - Sets ``amount`` and puts the three totals back to 0, 0 and 1.
   * - ``hit_position()``
     - func
     - ``position`` if it was recorded, otherwise where the target is.

StatModifier
~~~~~~~~~~~~

**What it is:** a ``Resource`` holding one change to one stat. It has no functions.

.. list-table::
   :header-rows: 1
   :widths: 25 20 55

   * - Member
     - Type
     - Purpose
   * - ``stat``
     - ``StringName``
     - Which stat, e.g. ``move_speed``.
   * - ``add``
     - ``float = 0.0``
     - Added to the base.
   * - ``percent``
     - ``float = 0.0``
     - A percentage: 0.1 is 10% more. Percentages add up before they're applied.
   * - ``mul``
     - ``float = 1.0``
     - Multiplies the total.
   * - ``conditions``
     - ``Array[Condition]``
     - The modifier only counts while all pass. Add this once stage 3 has conditions.

ComponentManager
~~~~~~~~~~~~~~~~

**What it is:** a ``Node`` that sits beside the components, one per character and one per item
scene. It is the hub: registry, stats and events.

.. list-table::
   :header-rows: 1
   :widths: 30 12 58

   * - Member
     - Kind
     - Purpose
   * - ``host``
     - var
     - The parent node: the character.
   * - ``started``
     - var
     - True once every component has had its chance to start.
   * - ``_components``
     - var
     - ``Array[Component]``.
   * - ``_modifiers``, ``_modifier_sources``
     - var
     - ``Array[StatModifier]``, and what added each one, in the same order.
   * - ``_cache``, ``_bases``
     - var
     - ``Dictionary[StringName, float]`` of computed stats, and of their base values.
   * - ``_subscribers``
     - var
     - Event name to a list of ``[priority, Callable, owner id]``, highest priority first.
   * - ``_found``
     - var
     - ``Dictionary[Script, Component]`` of ``find()`` answers.
   * - ``stat_changed(stat_name)``
     - signal
     - Emitted when a stat may have a new value.
   * - ``of(node)``
     - static
     - Tries the child named ``ComponentManager``, then searches ``node``'s children.
   * - ``notify(node, event, ctx = null)``
     - static
     - ``of(node).send(...)``, safe when there is no manager. Without ``ctx``, it makes one
       with ``node`` as the target.
   * - ``stat_of(node, name)``
     - static
     - ``of(node).stat(name)``, or 0.
   * - ``find(type)``
     - func
     - Scans ``host.get_children()`` the first time, so it works before the tree is built,
       and keeps the answer in ``_found`` until the host's children change.
   * - ``find_all(type)``
     - func
     - Every child of that type, for components a host can have several of.
   * - ``has_registered(type)``
     - func
     - True if a registered component is that type.
   * - ``send(event, ctx)``
     - func
     - Calls the subscribers with a priority above 0, then ``_on_event`` on every *running*
       component, then the other subscribers, then ``WorldEvents.emit``.
   * - ``subscribe(event, method, priority = 0)`` / ``unsubscribe(event, method)``
     - func
     - Add or remove one listener for one event. A listener whose object was freed is
       dropped when the event is next sent.
   * - ``stat(name)``
     - func
     - ``(base + Σadd) × (1 + Σpercent) × Πmul``, cached unless one of the stat's modifiers
       has conditions.
   * - ``base_of(name)`` / ``modifiers_of(name)``
     - func
     - The value before modifiers, and every modifier on the stat with its source, for a
       character sheet.
   * - ``add_modifier(m, source = null)`` / ``remove_modifier(m)``
     - func
     - Change both lists, clear that stat's cache entry, emit ``stat_changed``.
   * - ``refresh_stats()``
     - func
     - Clear the whole cache and emit for every stat name.
   * - ``register(c)`` / ``unregister(c)``
     - func
     - Called by components themselves. Clear the cache entries of the stats ``c`` owns and
       emit ``stat_changed`` for each.
   * - ``try_start(c)``
     - func
     - Starts ``c`` if the host is ready and nothing it requires is missing.
   * - ``_start_all()``
     - func
     - Tries every component, sets ``started``, sends the ``started`` event.

The stat formula, where the base comes from the first component whose ``_stats()`` lists the
name (0 if none does):

.. code-block:: text

    stat = (base + Σ add) × (1 + Σ percent) × Π mul

Lifecycle: on ``PARENTED``, connect ``host.child_order_changed`` to clear ``_found``, so a
lookup is redone whenever a child is added, removed or moved. On ``ENTER_TREE``, register any
Component children. On ``READY``, wait for ``host.ready``, then call ``_start_all()``.

.. graphviz::
   :caption: Component lifecycle. Every registration retries the components still waiting.

   digraph lifecycle {
       rankdir=LR;
       node [shape=box, style="rounded,filled", fillcolor="#e8f1fa", color="#3d8fcc"];
       edge [color="#7a7a7a"];
       registered [label="Registered\n(stats readable)"];
       waiting [label="Waiting\n(warning shown)"];
       running [label="Running\n(_start() ran)", fillcolor="#dff3e4", color="#3c9a5f"];
       registered -> running [label="host ready and\nrequirements present"];
       registered -> waiting [label="something missing"];
       waiting -> running [label="it arrives"];
       running -> waiting [label="a requirement\nleaves: _stop()"];
       running -> registered [label="leaves the tree:\n_stop()", style=dashed];
   }

A component that can't start yet isn't an error: it waits, and every later registration
retries it. Stopping is the mirror image, and a sibling that loses a requirement stops with it.

Component
~~~~~~~~~

**What it is:** the ``Node`` base class for every part. Subclasses override the virtuals;
everything else is plumbing.

.. list-table::
   :header-rows: 1
   :widths: 30 12 58

   * - Member
     - Kind
     - Purpose
   * - ``host``
     - var
     - The parent node.
   * - ``manager``
     - var
     - Its ComponentManager, set on register.
   * - ``running``
     - var
     - True between ``_start()`` and ``_stop()``.
   * - ``_connections``, ``_subscriptions``
     - var
     - What ``listen()`` and ``on()`` set up, so ``_halt()`` can undo it.
   * - ``_mode``
     - var
     - The ``process_mode`` to restore when the component starts.
   * - ``of(node, type)``
     - static
     - The component of ``type`` on ``node``, or null.
   * - ``find(type)``
     - func
     - A sibling component of ``type``.
   * - ``find_node_of_type(type)``
     - func
     - The first node of a built-in class under the host, e.g. a camera for an empty export.
   * - ``stat(name)``
     - func
     - Shortcut for ``manager.stat(name)``.
   * - ``find_all(type)``
     - func
     - Every sibling component of ``type``.
   * - ``listen(signal, callable)``
     - func
     - Connects and records it, so ``_halt()`` can undo it.
   * - ``on(event, method, priority = 0, node = null)``
     - func
     - Subscribes ``method`` to one event on this host's manager, or on ``node``'s, and
       records it, so ``_halt()`` can undo it.
   * - ``update_stats()``
     - func
     - Call after changing a value ``_stats()`` reads.
   * - ``missing()``
     - func
     - Types from ``_requires()`` that aren't registered.
   * - ``_requires()``
     - virtual
     - ``Array[Script]`` this component needs beside it.
   * - ``_stats()``
     - virtual
     - ``Dictionary[StringName, float]`` of stats it owns.
   * - ``_start()`` / ``_stop()``
     - virtual
     - Set up and tear down.
   * - ``_on_event(event, ctx)``
     - virtual
     - Sees every event. Most components use ``on()`` for the one or two they want.
   * - ``_warnings()``
     - virtual
     - Extra editor warnings, e.g. an export that must be set.
   * - ``_begin()`` / ``_halt()``
     - func
     - Called by the manager: flip ``running``, restore or disable ``process_mode``, call the
       virtual, and on halt undo everything from ``listen()`` and ``on()``. ``_begin()`` also
       keeps what ``_requires()`` returned, for ``unregister``.

WorldEvents
~~~~~~~~~~~

**What it is:** a class with only static functions, which hears every host's events: any
death, any kill. Experience, quests and kill feeds listen here instead of to each character.

.. list-table::
   :header-rows: 1
   :widths: 30 12 58

   * - Member
     - Kind
     - Purpose
   * - ``on(event, method)`` / ``off(event, method)``
     - static
     - Add or remove a listener. It's called with the host and the context.
   * - ``emit(host, event, ctx)``
     - static
     - Called at the end of ``ComponentManager.send()``.
   * - ``owner_of(method)`` / ``is_alive(method, owner)``
     - static
     - The id of a listener's object, taken when it subscribes, and whether that object
       still exists.

Watch out for
~~~~~~~~~~~~~

- **Register in** ``ENTER_TREE``, **not** ``READY``. Children are ready before their parent,
  so components would otherwise run before the manager knows about them.
- **Disable the node until it starts.** At ``READY``, save ``process_mode`` in ``_mode`` and set
  ``PROCESS_MODE_DISABLED``; ``_begin()`` restores it. A disabled node gets no ``_process``,
  ``_physics_process`` or input, so those callbacks can use what ``_requires()`` promises
  without null checks.
- **Copy a list before looping over it if the loop can change it.** An event can remove a
  component mid-loop.
- **On unregister, stop anything that lost a requirement.** Only the running components that
  required the leaving one's type are checked, and any whose ``missing()`` is no longer empty
  halts. ``try_start`` brings it back if the missing part returns.
- **Remember lookups, and forget them when children change.** Components call ``find()`` every
  frame. Scanning the children each time costs a list copy per call; a dictionary that's
  cleared on ``child_order_changed`` costs one lookup.
- **Keep global listeners on the scene tree's root, not in a static variable.** WorldEvents
  stores them as metadata on the root window, so they are freed with the game. Callables left
  in a static variable when the game quits can crash on exit.
- **Record who owns a listener when it subscribes.** A lambda still looks valid after the
  object it was written in is freed, so asking the Callable later isn't enough. Keep the
  object's instance id beside it and check ``is_instance_id_valid()`` before each call.
- **A conditional stat can read itself.** A condition on a ``power`` modifier may test
  ``power``. Mark a stat as being worked out, and return its base value to any read that
  arrives meanwhile.

Test
~~~~

Make two dummy components where B requires A. Add A after B and check that B starts. Remove A
and check that B stops. Add a modifier with ``add = 2, mul = 1.5`` to a base of 10 and check you
get 18. Subscribe three methods to one event with priorities 10, 0 and -10 and check they hear
it in that order.

Stage 2: First real components
------------------------------

These components on top of the core give you a character that walks, has health, mana and
stats of its own, and knows its team. All extend ``Component``.

.. list-table::
   :header-rows: 1
   :widths: 15 35 50

   * - Class
     - Data
     - Must implement
   * - ``Health``
     - ``max_health``, ``resistances: Dictionary[type, float]``, ``current``, ``_full``;
       signals ``changed(current, maximum)``, ``died(ctx)``
     - ``_stats()`` returns ``max_health`` and one ``resist_<type>`` per entry; ``maximum()``,
       ``is_dead()``, ``change(amount, ctx)``, ``revive(amount)``; clamp ``current`` when
       ``max_health`` drops. On death, send ``died`` to the host and ``killed`` to
       ``ctx.source``; ``revive()`` sends ``revived``
   * - ``Attributes``
     - ``stats: Dictionary[StringName, float]``
     - ``_stats()`` returns the dictionary, so a game's own stats need no script;
       ``set_base(name, value)``, ``add_base(name, amount)``
   * - ``Pool``
     - ``pool`` (its name), ``max_value``, ``regen``, ``regen_delay``, ``starts_full``,
       ``absorbs_damage``, ``absorbed_types``, ``current``; signals
       ``changed(current, maximum)``, ``emptied``
     - ``_stats()`` returns ``max_<pool>`` and ``<pool>_regen``; ``named(node, name)``
       (static), ``maximum()``, ``fraction()``, ``spend(amount) -> bool``, ``change(amount)``;
       regen in ``_process`` once the delay has passed; on ``absorbing_damage``, take what it
       can from ``ctx.amount``
   * - ``Brain``
     - ``move_dir``, ``aim_point``, ``blocked_by_tags``, ``acts_while_dead``, ``_held``,
       ``_pressed_on``
     - ``press(action)``, ``release(action)``, ``is_action_pressed(action)``,
       ``is_action_just_pressed(action)``. It's the shared interface that the motor, Abilities
       and items read, the way your scripts read Godot's ``Input``. ``is_blocked()`` is true
       while the character is dead or has a status with one of ``blocked_by_tags``; then
       ``move_dir`` reads as zero and no action counts as pressed
   * - ``PlayerBrain``
     - ``camera`` (empty: the first ``Camera3D`` under the host), ``ACTIONS`` list
     - Fill ``move_dir`` and ``aim_point`` in ``_process``, and release any held action
       ``Input`` no longer has pressed; record presses from ``_unhandled_input``
   * - ``AIBrain``
     - ``agent: NavigationAgent3D`` (empty: the first one under the host),
       ``repath_distance``, ``target``
     - Steer ``move_dir`` toward the next path point in ``_physics_process``, setting
       ``agent.target_position`` only once the target has moved ``repath_distance``; decision
       logic calls ``press()`` and ``release()``
   * - ``CharacterMotor``
     - ``move_speed``, ``jump_velocity``, ``start_mode``, ``push_friction``, ``mode``,
       ``brain``, ``body``, ``_modes``, ``_moves``, ``_consumed``, ``_push``; signal
       ``mode_changed(old_mode, new_mode)``
     - ``_requires()`` returns ``[Brain]``; ``_stats()`` returns ``move_speed``,
       ``jump_velocity`` and its children's stats; ``consume_action(action)``,
       ``get_mode(type)``, ``push(velocity)``; ``_physics_process`` runs the mode's
       ``_physics_update()``, then each active move's, calls ``move_and_slide()``, then
       switches to the mode's ``_get_next_mode()`` or to another mode whose ``_can_enter()``
       is true
   * - ``MotorNode``, ``MovementMode``, ``LayeredMove``
     - ``blocked_by_tags``; ``motor``, ``body`` and ``event_prefix``, set when entering the
       tree; a move's ``cooldown``, ``active`` and signals ``started``, ``finished``
     - Empty hooks ``_stats()``, ``_enter()``, ``_exit()`` and ``_physics_update(delta)``;
       ``stat()``, ``is_blocked()``; a mode's ``_can_enter()`` and ``_get_next_mode()``; a
       move's ``_can_start()`` and ``cooldown_left()``. Setting ``active`` starts the
       cooldown timer and sends ``<event_prefix>_started`` or ``_finished``
   * - ``WalkMode``, ``AirMode``
     - ``jump_action``; ``air_mode`` or ``walk_mode`` (empty: the other one); AirMode's
       ``air_jumps``, ``air_acceleration`` and ``jumps_left``
     - Set velocity as Godot's CharacterBody3D template does; jump on
       ``motor.consume_action(jump_action)``; hand over when the floor is gone or reached.
       AirMode owns ``air_jumps`` and refills ``jumps_left`` in ``_enter()``
   * - ``Faction``
     - ``team``, ``hostile_to``
     - ``_start()`` adds the host to the group named ``team``, ``_stop()`` removes it;
       ``is_hostile(other)`` checks ``other``'s groups
   * - ``MouseLook``
     - ``camera`` (empty: the first ``Camera3D`` under the host), ``sensitivity``,
       ``capture_on_start``
     - Rotate the host and camera in ``_unhandled_input``

How a brain remembers presses, modelled on Godot's ``Input``:

.. literalinclude:: ../../character_system/characters/brains/_base/brain.gd
   :language: gdscript
   :caption: character_system/characters/brains/_base/brain.gd (variables)
   :start-at: var _pressed_on
   :end-at: var _held

.. literalinclude:: ../../character_system/characters/brains/_base/brain.gd
   :language: gdscript
   :caption: character_system/characters/brains/_base/brain.gd (functions)
   :start-at: func press(

Watch out for
~~~~~~~~~~~~~

- **Health needs a** ``_full`` **flag.** Until the manager sends ``started``, ``current``
  follows ``maximum()``, so a character spawned with a max-health buff starts full. After that,
  raising the maximum doesn't heal, and lowering it clamps ``current``.
- **Health listens to** ``manager.stat_changed`` with ``listen()``, so the connection is undone
  when Health stops.
- **Stop the brain, not each reader.** A stun or a death makes the Brain report no intent, so
  the motor, weapons and abilities all stop without knowing why. ``Statuses`` doesn't exist
  until stage 4; ``is_blocked()`` finds it with ``find()`` and copes with it being absent.
- **A shield is a pool that listens.** ``Pool`` needs no special case in the damage code: it
  subscribes to ``absorbing_damage`` with a low priority and lowers ``ctx.amount``.
- **Brains are swappable.** The motor only knows ``Brain``, so the same body works for a
  player or an AI. That's why it requires the base class, not ``PlayerBrain``.
- **One mode at a time, one use per press.** Only the current mode runs, and
  ``consume_action()`` remembers which presses were used this frame, so the press that jumps
  from the floor can't also spend an air jump, whatever order the nodes are in.
- **Statuses and events go through the motor.** It skips blocked modes and moves, and sends
  ``<event_prefix>_entered`` and ``_exited`` when the mode changes, except for the first mode,
  so features written later get both without code of their own.
- **Modes and moves are plain nodes.** They live under the motor, which lists them again
  whenever its children change (``NOTIFICATION_CHILD_ORDER_CHANGED``), so they can be added and
  removed during play.
- **A press from code counts from the next frame.** ``press()`` can be called at any point in a
  frame, even after some nodes already ran their ``_process``. Counting it from the next frame
  means every node sees it as just pressed exactly once. Presses from input events arrive
  before the frame's processing, so ``PlayerBrain`` counts them in the current frame, as
  ``Input`` does.
- **Poll releases, don't wait for them.** A button let go while the game is paused, over the UI
  or in another window never sends a release event to ``_unhandled_input``. ``PlayerBrain``
  checks ``Input.is_action_pressed()`` every frame instead, so nothing stays held.
- **Don't set** ``target_position`` **every frame.** Godot finds a whole new path each time it's
  set, even to the same point. ``AIBrain`` only sets it once the target has moved
  ``repath_distance`` metres.

Test
~~~~

A capsule that walks with WASD and jumps with Space. Add a ``StatModifier`` with ``mul = 2`` on
``move_speed`` through ``manager.add_modifier`` and check it moves twice as fast. Remove it and
check the speed returns. Spend from a mana Pool until ``spend()`` refuses, and watch it refill.

Stage 3: Effects and conditions
-------------------------------

Effects are ``Resource``\ s that do one thing to an ``EffectContext``. Conditions are
``Resource``\ s that answer yes or no, and amounts are ``Resource``\ s that work out a number.
Because all three are resources, you build abilities, statuses and items in the Inspector
instead of in code.

Condition
~~~~~~~~~

.. list-table::
   :header-rows: 1
   :widths: 25 12 63

   * - Member
     - Kind
     - Purpose
   * - ``Subject``
     - enum
     - ``TARGET`` or ``SOURCE``: which side to check.
   * - ``subject``
     - export
     - Defaults to ``TARGET``.
   * - ``negate``
     - export
     - Flips the result ("target is NOT wet").
   * - ``check(ctx)``
     - func
     - Picks the node ``subject`` points to and returns ``_test(node) != negate``.
   * - ``_test(node)``
     - virtual
     - Returns true if the node passes. The node may be null or have no components.
   * - ``all_pass(list, ctx)``
     - static
     - True if every condition passes. An empty list passes.

Subclasses to write: ``HasTagCondition(tag)``, ``HealthBelowCondition(fraction)``,
``StatCondition(stat, value)`` and ``ChanceCondition(chance, bonus_stat)`` override
``_test()``. ``DamageTypeCondition(types)``, ``HitTagCondition(tag)`` and
``AnyCondition(conditions)`` override ``check()``; the first two read ``ctx.hit()``, so they
work inside status triggers.

Amount
~~~~~~

**What it is:** a ``Resource`` that works out a number when an effect runs, so damage can
grow with a stat.

.. list-table::
   :header-rows: 1
   :widths: 25 12 63

   * - Member
     - Kind
     - Purpose
   * - ``value(ctx)``
     - virtual
     - The number for this use. The base class returns 0.
   * - ``total(base, scaling, ctx)``
     - static
     - ``base`` plus the ``value()`` of everything in ``scaling``. Effects call this.

Subclasses to write: ``StatAmount(stat, of, per_point, curve)``,
``HealthAmount(of, part, fraction)``, ``HitAmount(fraction)`` (a share of ``ctx.cause.amount``)
and ``RandomAmount(low, high)``.

Effect
~~~~~~

.. list-table::
   :header-rows: 1
   :widths: 25 12 63

   * - Member
     - Kind
     - Purpose
   * - ``conditions``
     - export
     - ``Array[Condition]``. All must pass for the effect to run.
   * - ``apply(ctx)``
     - func
     - Runs ``_execute(ctx)`` only if ``Condition.all_pass(conditions, ctx)``.
   * - ``_execute(ctx)``
     - virtual
     - The effect itself.
   * - ``apply_all(effects, ctx)``
     - static
     - Applies a list in order.

DamageEffect
~~~~~~~~~~~~

Exports ``amount``, ``scaling: Array[Amount]``, ``type`` (e.g. ``physical``, ``fire``) and
``tags``. It is the pipeline every damage hook plugs into, and the order of its steps is what
makes shields, crits and thorns possible. A target that is already dead is skipped.

.. graphviz::
   :caption: The DamageEffect pipeline, and who hears each event.

   digraph damage {
       rankdir=TB;
       node [shape=box, style="rounded,filled", fillcolor="#e8f1fa", color="#3d8fcc", width=3.2];
       edge [color="#7a7a7a"];
       s1 [label="1. amount = (amount + scaling) × magnitude\npercent = source's bonus_<type>"];
       s2 [label="2. dealing_damage → source"];
       s3 [label="3. taking_damage → target"];
       s4 [label="4. amount = resolve() × (1 − resist)"];
       s5 [label="5. absorbing_damage → target"];
       s6 [label="6. health.change(−max(amount, 0))", fillcolor="#fbe9e7", color="#d9534f"];
       s7 [label="7. dealt_damage → source"];
       s8 [label="8. took_damage → target"];
       s1 -> s2 -> s3 -> s4 -> s5 -> s6 -> s7 -> s8;
   }

Events 2 and 3 run before the hit lands. Their listeners don't change ``ctx.amount``; they
add to ``ctx.add``, ``ctx.percent`` and ``ctx.mul``, and step 4 applies the totals once:

.. code-block:: text

    amount = (amount + add) × (1 + percent) × mul × (1 − resist_<type>)

Armour of -3 and a shield of ×0.5 therefore give the same result whichever was applied first.
``resist`` is capped at 1, so resistance never heals, and a negative value is a weakness.
Event 5 sees the final number, so a shield knows how much to soak up. Events 7 and 8 run
after, so their statuses can only react.

Other effects
~~~~~~~~~~~~~

- ``HealEffect(amount, scaling)``: the same steps without a type or resistance, sending
  ``giving_healing`` and ``receiving_healing`` before and ``gave_healing`` and
  ``received_healing`` after.
- ``ChangePoolEffect(pool, amount, scaling)``: ``Pool.named(target, pool).change(...)``.
- ``KnockbackEffect(strength, lift)``: calls ``CharacterMotor.push`` on the target, away from
  the source.

Hurtbox
~~~~~~~

**What it is:** an optional ``Area3D`` hit zone (head, armour plate) that passes hits to its
character.

.. list-table::
   :header-rows: 1
   :widths: 25 12 63

   * - Member
     - Kind
     - Purpose
   * - ``character``
     - export
     - The character it belongs to. Defaults to the scene owner.
   * - ``multiplier``
     - export
     - Scales effects that land here, e.g. 2.0 for a headshot.
   * - ``tags``
     - export
     - Labels put on every hit that lands here, e.g. ``head``.
   * - ``hit(source, collider, origin, position, normal)``
     - static
     - Builds the ``EffectContext``: resolves a hurtbox to its character, sets ``magnitude``
       and ``tags``, and records where the hit landed.
   * - ``rids_of(character)``
     - static
     - The body and hurtbox RIDs, so a character's own shots ignore them. It searches the
       whole character, so weapons call it once, on equip.

Watch out for
~~~~~~~~~~~~~

- **Clamp the final amount at 0** before ``health.change``, or a big shield heals.
- **Collect changes, apply them once.** If each listener edits the amount as it hears the
  event, the result depends on the order statuses were applied in. Totals don't.
- **One context can carry several effects.** A rifle with two DamageEffects passes the same
  context to both, so each one resets the totals before it starts, and puts back the tags it
  added when it's done.
- **Effects must survive missing components.** ``Component.of(target, Health)`` can be null;
  return quietly.

Test
~~~~

A key that applies ``DamageEffect(10, "fire")`` to a dummy. Give the dummy
``resistances = {fire: 0.5}`` and check it loses 5. Give the attacker an ``Attributes`` with
``strength`` 5 and the effect a ``StatAmount`` of 2 per point, and check the dummy loses 10.

Stage 4: Statuses
-----------------

This is the Baldur's Gate 3 part, and the stage where most design decisions live. A status is
data (``StatusData``) applied to a character by one component (``Statuses``). It changes stats
through modifiers and reacts to events through triggers. Expect to rewrite it once.

StatusTrigger
~~~~~~~~~~~~~

**What it is:** a ``Resource`` that runs effects when an event reaches the status holder.

.. list-table::
   :header-rows: 1
   :widths: 25 20 55

   * - Member
     - Type
     - Purpose
   * - ``event``
     - ``StringName``
     - e.g. ``taking_damage``, ``dealt_damage``, ``killed``, ``died``.
   * - ``conditions``
     - ``Array[Condition]``
     - Checked once before any effect, so a chance rolls once for the whole trigger.
   * - ``affects_other``
     - ``bool``
     - Target the other side of the event, e.g. thorns hits the attacker.
   * - ``react_to_statuses``
     - ``bool``
     - Also react when a status caused the event (poison ticks).
   * - ``effects``
     - ``Array[Effect]``
     - What to run.

StatusData
~~~~~~~~~~

**What it is:** a ``Resource``, mostly exports, grouped as they appear in the Inspector.

.. list-table::
   :header-rows: 1
   :widths: 15 85

   * - Group
     - Members
   * - Display
     - ``id``, ``display_name``, ``icon``, ``description``
   * - Rules
     - ``tags``, ``immune_to``, ``apply_conditions``, ``duration`` (0 = permanent, a passive),
       ``stacking`` (``REFRESH`` / ``STACK`` / ``IGNORE``), ``max_stacks``, ``removes_tags``
   * - Effects
     - ``modifiers``, ``tick_interval``, ``on_apply``, ``on_tick``, ``on_remove``, ``triggers``
   * - Functions
     - ``stack_limit()``: ``max_stacks`` if stacking, else 1. ``can_apply(target, source)``:
       false if the target's ``Statuses.is_immune_to(self)``, or ``apply_conditions`` fail.

Statuses
~~~~~~~~

**What it is:** the ``Component`` that holds a character's active statuses. It is the hardest
class in the system.

.. list-table::
   :header-rows: 1
   :widths: 30 12 58

   * - Member
     - Kind
     - Purpose
   * - ``innate``
     - export
     - Statuses the character always has. Added in ``_start()``.
   * - ``active``
     - var
     - ``Dictionary[StatusData, ActiveStatus]``.
   * - ``ActiveStatus``
     - inner class
     - ``stacks``, ``time_left``, ``tick_in``, ``holds``, ``source``.
   * - ``changed`` / ``refused(data, source)``
     - signals
     - For UI and feedback.
   * - ``add(data, source)``
     - func
     - Applies a status. Returns false if refused. The flow is drawn below.
   * - ``remove(data)``
     - func
     - Strips every stack's modifiers, erases the entry, runs ``on_remove``.
   * - ``drop_hold(data)``
     - func
     - Drops one permanent hold (unequip, leave a zone). Removes the status only when no holds
       are left.
   * - ``remove_tagged(tag)``
     - func
     - Removes every status with the tag, for an antidote.
   * - ``has_tag(tag)``
     - func
     - True if any active status has the tag.
   * - ``is_immune_to(data)``
     - func
     - True if an active status's ``immune_to`` covers one of ``data``'s tags. ``add()``
       refuses those.
   * - ``_set_stacks(data, s, n)``
     - func
     - Adds or removes ``data.modifiers`` once per stack through ``manager.add_modifier``,
       naming the status as their source. This is how statuses change stats.
   * - ``_process(delta)``
     - func
     - Counts down durations; runs ``on_tick`` every ``tick_interval``. Only turned on (with
       ``set_process``) while a status has a duration or a tick interval.
   * - ``_on_event(event, ctx)``
     - func
     - On ``died``, ends timed statuses. Then, if ``ctx`` isn't null, runs the effects of each
       trigger whose event matches.
   * - ``_run(effects, data, s, target, cause, conditions)``
     - func
     - Builds a context with ``magnitude = stacks``, ``from_status = true``, ``cause = ctx``
       and ``depth`` one more than the cause's, then applies the effects if the conditions
       pass. Does nothing once the cause's depth has reached ``MAX_DEPTH``.
   * - ``_stop()``
     - func
     - Takes every status's modifiers back off, without running ``on_remove``.

.. graphviz::
   :caption: Statuses.add(). Only the highlighted step changes stats.

   digraph add {
       rankdir=TB;
       node [shape=box, style="rounded,filled", fillcolor="#e8f1fa", color="#3d8fcc"];
       edge [color="#7a7a7a"];
       can [label="can_apply()?", shape=diamond, style=filled];
       refused [label="emit refused, return false", fillcolor="#fbe9e7", color="#d9534f"];
       clear [label="remove statuses with a tag in removes_tags"];
       entry [label="new ActiveStatus, or the existing one;\nholds + 1 if permanent"];
       ignore [label="already active and\nstacking is IGNORE?", shape=diamond, style=filled];
       done [label="return true"];
       refresh [label="set source, reset time_left"];
       stack [label="below stack_limit()?", shape=diamond, style=filled];
       more [label="_set_stacks(+1), run on_apply", fillcolor="#dff3e4", color="#3c9a5f"];
       can -> refused [label="no"];
       can -> clear [label="yes"];
       clear -> entry -> ignore;
       ignore -> done [label="yes"];
       ignore -> refresh [label="no"];
       refresh -> stack;
       stack -> more [label="yes"];
       stack -> done [label="no"];
       more -> done;
   }

Each stack adds the status's modifiers once more, so multipliers compound per stack.

Status effects
~~~~~~~~~~~~~~

.. list-table::
   :header-rows: 1
   :widths: 25 25 50

   * - Class
     - Exports
     - Does
   * - ``ApplyStatusEffect``
     - ``status``
     - ``Statuses.add(status, ctx.source)`` on the target.
   * - ``RemoveStatusEffect``
     - ``status``, ``tag``, ``drop_hold_only``
     - ``remove()``, or ``drop_hold()`` when ``drop_hold_only`` is set; ``remove_tagged()``
       for the tag.
   * - ``ModifyAmountEffect``
     - ``add``, ``percent``, ``mul``, ``per_stack``, ``tag``
     - Adds to the totals of ``ctx.cause``: ``add``, ``percent`` and ``mul``. Only does
       something inside a trigger.

EffectZone
~~~~~~~~~~

**What it is:** an ``Area3D`` that applies effects to bodies entering and leaving it.

.. list-table::
   :header-rows: 1
   :widths: 30 12 58

   * - Member
     - Kind
     - Purpose
   * - ``status_while_inside``
     - export
     - Added on enter, its hold dropped on exit.
   * - ``on_enter`` / ``on_exit``
     - export
     - Effect lists.
   * - ``_holding``
     - var
     - Bodies that accepted the status, so only their holds are dropped.
   * - ``_exit_tree()``
     - func
     - Drops the hold of everyone still inside when the zone is freed.

Watch out for
~~~~~~~~~~~~~

- ``drop_hold`` **is not** ``remove``. A permanent status can be held by a ring and a zone at
  once. Count holds; take it off only when the last one lets go.
- **Loop over** ``active.keys()``, **not** ``active``. Effects can add or remove statuses
  mid-loop. Check ``active.has(data)`` before each trigger.
- **Credit the right side.** In ``_run``, effects on the holder credit whoever applied the
  status; effects on others credit the holder.
- ``from_status`` **breaks loops.** Without it, a thorns status on two characters hits back
  and forth forever. ``depth`` is the backstop for triggers that ask to react to statuses.
- ``on_remove`` **is for a status that ends.** ``_stop()`` runs when a character is freed, so
  running ``on_remove`` there would set off every "bursts when it ends" status at each despawn
  and level change. It only takes the modifiers off.
- **Triggers need a context.** Events sent with a null ``ctx``, such as ``started`` and
  ``inventory_changed``, reach components but no status triggers.

Test
~~~~

Poison (duration 6, tick 1, ``DamageEffect`` 2 poison) ticks once a second until it ends. Wet
(``removes_tags: [burning]``) puts out Burning, and with ``immune_to: [fire]`` Burning can't
come back while it's wet. An Undead trait with ``immune_to: [poison]`` refuses Poison. A ward
(``taking_damage`` trigger, ``react_to_statuses``, ``ModifyAmountEffect`` ``mul 0.5``) halves
hits, and with armour (``add -3``) beside it a hit of 10 lands for 3.5 whichever was added
first. A passive granted by a ring and a zone stays until both let go. A status tagged
``stunned`` stops the capsule from stage 2.

Stage 5: Items
--------------

Items split into data (what the item is), an instance (this copy) and a scene (what it does when
held). An item scene is a small character of its own: it has a ComponentManager, and its parts
are ``ItemComponent``\ s.

Data classes
~~~~~~~~~~~~

.. list-table::
   :header-rows: 1
   :widths: 18 15 67

   * - Class
     - Extends
     - Members
   * - ``ItemData``
     - ``Resource``
     - ``id``, ``display_name``, ``icon``, ``description``, ``max_stack``, ``slot``, ``scene``
       (the PackedScene equipped), ``use_effects``, ``consumed_on_use``
   * - ``ItemInstance``
     - ``Resource``
     - ``data``, ``count``, ``state: Dictionary`` for per-copy values such as rounds loaded;
       ``_init(data, count)``

Character components
~~~~~~~~~~~~~~~~~~~~

.. list-table::
   :header-rows: 1
   :widths: 15 35 50

   * - Class
     - Data
     - Must implement
   * - ``Inventory``
     - ``items: Array[ItemInstance]``; signal ``changed``
     - ``count(data)``, ``add(data, n)`` respecting ``max_stack``, ``add_instance(item)``,
       ``remove(data, n) -> bool``, ``first(data)``, ``remove_instance(item) -> bool``. Every
       change emits ``changed`` and sends the ``inventory_changed`` event. ``use(data)`` runs
       the item's ``use_effects`` on the host and takes one from the stack.
   * - ``Equipment``
     - ``sockets: Dictionary[slot, NodePath]``, ``equipped``, ``_nodes``; signal
       ``changed(slot)``
     - ``equip(item)`` and ``unequip(slot) -> ItemInstance``; on ``inventory_changed``,
       unequip anything no longer carried. The equip order is listed below.
   * - ``WeaponSwitch``
     - ``slot``, ``auto_draw``, ``_holstered``
     - ``_requires()`` returns ``[Brain, Inventory, Equipment]``; ``weapons()``, ``current()``,
       ``cycle(step)``, ``select(index)``, ``holster()``; switch on ``next_weapon`` and
       ``previous_weapon`` in ``_process``; on ``inventory_changed``, draw a weapon if the hands
       are empty

``equip(item)`` in order:

1. Return if ``item`` is already in its slot.
2. With an ``Inventory`` beside it, add ``item`` if it isn't carried. Equipped means carried.
3. Unequip whatever is in ``item.data.slot``. It stays in the Inventory.
4. Instantiate ``item.data.scene``.
5. Set ``wielder`` and ``item`` on every ``ItemComponent`` child.
6. Add the scene under the slot's socket. Its own ComponentManager starts its components.
7. Record it in ``equipped`` and ``_nodes``, then emit ``changed(slot)``.

``unequip(slot)`` frees the node, erases both entries, emits ``changed`` and returns the
``ItemInstance``, which stays carried.

Item components
~~~~~~~~~~~~~~~

All extend ``ItemComponent``, which extends ``Component`` and adds ``wielder`` (the
character), ``item`` (the ``ItemInstance``) and a ``brain`` getter that returns the wielder's
Brain.

.. list-table::
   :header-rows: 1
   :widths: 15 35 50

   * - Class
     - Data
     - Must implement
   * - ``Trigger``
     - ``action``, ``fire_rate``, ``automatic``, ``buffer_time``, ``blocked_by_tags``,
       ``_buffered``, ``_cooldown``; signal ``fired``
     - In ``_process``: buffer a press when ``brain.is_action_just_pressed(action)``; with
       ``automatic``, also want to fire while ``is_action_pressed``; when the cooldown is over
       and the wielder has none of ``blocked_by_tags``, take a round from a ``Magazine`` if
       there is one, then emit ``fired``
   * - ``Magazine``
     - ``ammo: ItemData``, ``capacity``, ``reload_time``, ``auto_reload``, ``rounds`` (stored
       in ``item.state``); signals ``changed(rounds)``, ``reload_started``,
       ``reload_finished``
     - ``take() -> bool``, ``reload()`` pulling ammo from the wielder's Inventory, at once or
       after ``reload_time``; ``is_reloading()``; reload on
       ``is_action_just_pressed(&"reload")``
   * - ``Hitscan``
     - ``max_distance``, ``collision_mask``, ``pellets``, ``spread``, ``effects``
     - ``_requires()`` returns ``[Trigger]``; ``_start()`` keeps ``Hurtbox.rids_of(wielder)``;
       on ``fired``, for each pellet raycast toward ``brain.aim_point`` excluding those RIDs,
       build the context with ``Hurtbox.hit()``, then ``Effect.apply_all``
   * - ``Launcher``
     - ``projectile: PackedScene``, ``effects``, ``count``, ``spread``
     - ``_requires()`` returns ``[Trigger]``; on ``fired``, ``Projectile.launch()`` from the
       item toward ``brain.aim_point``
   * - ``GrantStatuses``
     - ``statuses``, ``_granted``
     - ``_start()``: add each status, keeping only those accepted; ``_stop()``: drop the hold
       of only those
   * - ``GrantModifiers``
     - ``modifiers``, ``_applied``
     - ``_start()``: add each modifier, and any in ``item.state[&"modifiers"]``, to the
       wielder's manager; ``_stop()``: remove them
   * - ``GrantAbilities``
     - ``abilities: Dictionary[action, AbilityData]``, ``_previous``
     - ``_start()``: put each in the wielder's ``Abilities.slots``, remembering what was
       there; ``_stop()``: put it back

Projectile
~~~~~~~~~~

**What it is:** a ``Node3D`` script for shots that take time to arrive. It isn't a component.

.. list-table::
   :header-rows: 1
   :widths: 30 12 58

   * - Member
     - Kind
     - Purpose
   * - ``speed``, ``gravity_scale``, ``lifetime``, ``collision_mask``
     - export
     - How it flies and what it can hit.
   * - ``effects``
     - export
     - Applied to what it hits, after any the launcher handed over.
   * - ``blast_radius``, ``blast_effects``, ``blast_edge_strength``, ``impact_scene``
     - export
     - What happens around the point of impact.
   * - ``source``, ``origin``, ``velocity``
     - var
     - Who launched it, the item or ability behind it, and where it's heading.
   * - ``launch(scene, source, from, toward, extra_effects, origin)``
     - static
     - Instantiates the scene, adds it to the level, aims it and returns it.
   * - ``spread_direction(direction, degrees)``
     - static
     - A direction turned by a random angle, shared with ``Hitscan``.
   * - ``_physics_process(delta)``
     - func
     - Casts a ray from where it is to where it will be. On a hit, applies the effects, then
       the blast, and frees itself.

Watch out for
~~~~~~~~~~~~~

- **Set** ``wielder`` **and** ``item`` **before** ``add_child``. Then both are ready when the
  item's components start.
- **Keep per-copy state in** ``item.state``, **not on the node.** The node is freed on unequip;
  the instance survives, so rounds loaded are remembered, even when switching weapons back and
  forth.
- **Drop only the holds you added.** If a status was refused (blocked or immune),
  ``GrantStatuses`` must not drop its hold, or it would drop a hold someone else owns.
- **Draw after the change, not during it.** ``WeaponSwitch`` reacts to ``inventory_changed``
  with ``call_deferred``, so it never equips in the middle of the Inventory changing.
- **Keep what a frame overshot the fire rate by.** Setting the cooldown to ``1 / fire_rate``
  after each shot throws the overshoot away, so the weapon fires slower at low frame rates.
  Add the interval to what's left instead, limited to one frame's worth.
- **Move a projectile with a ray, not an Area3D.** A fast shot can pass through a thin wall
  between two frames. A ray from the old position to the new one can't miss it.
- **Add projectiles to the level, deferred.** They must outlive their launcher, and effects
  can run inside physics callbacks, where nodes can't be added yet.

Test
~~~~

Equip a rifle, shoot a dummy, empty the magazine and reload from the inventory. Pick up a second
weapon, switch to it and back, and check the rifle kept its rounds. Drop the held weapon and
check the other one is drawn. Equip a ring with a +20 ``max_health`` passive and check the
maximum rises without healing. Fire a projectile with a blast at two dummies standing together
and check both are hurt.

Stage 6: Abilities
------------------

Abilities reuse everything above: an ability is a set of rules for when it can be used, a way
to pick targets, and a list of effects.

.. list-table::
   :header-rows: 1
   :widths: 15 15 70

   * - Class
     - Extends
     - Members
   * - ``Targeting``
     - ``Resource``
     - ``find(ctx) -> Array[Node]``. The base version returns ``[ctx.source]`` (the user).
       Subclasses return what a ray, sphere or cone finds; the reference build's
       ``RadiusTargeting`` asks the physics engine for everything in a sphere.
   * - ``AbilityData``
     - ``Resource``
     - Display: ``id``, ``display_name``, ``icon``, ``description``. Use: ``cooldown``,
       ``charges``, ``costs: Dictionary[pool, float]``, ``conditions``, ``blocked_by_tags``.
       Casting: ``cast_time``, ``status_while_casting``, ``interrupted_by_damage``. Effects:
       ``targeting``, ``needs_target``, ``effects``, ``user_effects``
   * - ``Abilities``
     - ``Component``
     - ``slots: Dictionary[action, AbilityData]``, ``cooldown_speed`` (a stat), ``casting``,
       ``_states: Dictionary[AbilityData, State]`` holding charges used and the time until
       the next one; signals ``used``, ``cast_started``, ``cast_interrupted``,
       ``failed(ability, reason)``; ``_requires()`` returns ``[Brain]``; ``_process`` counts
       cooldowns and the cast down, then uses each slot whose action
       ``is_action_just_pressed``; ``use(ability) -> bool``, ``can_use()``, ``why_not()``,
       ``interrupt()``, ``cooldown_left()``, ``recharge_left()``, ``charges_left()``,
       ``cast_progress()``, ``reset_cooldown()``
   * - ``LaunchProjectileEffect``
     - ``Effect``
     - ``projectile``, ``effects``, ``height``, ``forward``. Launches from the source toward
       its Brain's ``aim_point``, for a fireball in ``user_effects``.

``use(ability)`` in order:

1. Ask ``why_not(ability)``. It names the first thing against it: the Brain is blocked or a
   status has one of ``blocked_by_tags``, another cast is under way, no charge is ready, a
   Pool can't pay, a condition fails, or it needs a target and has none. If there is one, emit
   ``failed`` with it and return false.
2. With a ``cast_time``, remember the ability in ``casting``, give the user
   ``status_while_casting`` and return true. ``_process`` counts the cast down, interrupts it
   if the ability becomes blocked, and fires it when the time is up.
3. To fire: take the costs from the Pools and one charge, starting the cooldown if no charge
   was already coming back.
4. Ask ``targeting.find()`` for targets, or use the host if there is no Targeting. For each
   target, apply ``effects`` with a fresh ``EffectContext(host, target, ability)``, then apply
   ``user_effects`` to the host.
5. Emit ``used`` and send the ``ability_used`` event.

Cooldowns are counted in ``_process``, scaled by the ``cooldown_speed`` stat, so they stop
while the game is paused and follow ``Engine.time_scale``.

Test
~~~~

A heal on ``secondary`` that targets the user, and a fireball that applies ``DamageEffect`` plus
``ApplyStatusEffect(Burning)`` to everything in a sphere. Press twice quickly and check the
cooldown blocks the second use, and that pausing the game pauses the cooldown. Give the
fireball a mana cost and a cast time, and check that being stunned mid-cast spends nothing.

What to skip the first time
---------------------------

These were added late in the reference build and are easier once everything else works:

- **Editor support:** ``@tool``, ``_get_configuration_warnings``, and the ``is_tool()`` check
  needed because non-``@tool`` scripts are placeholders in the editor.
- **Name warnings:** :ref:`NameCheck <doc_editor_warnings_for_names>` and the Character System
  Warnings add-on, which catch mistyped stat, event and tag names.
- **Node icons** and ``##`` doc comments.
- **"Report missing once" error messages** in ``try_start``.

- **The extras on abilities and weapons:** charges, cast time, reload time, spread and
  projectiles. A cooldown, a ray and an instant reload are enough to play with.

Get stages 1–3 running with plain ``print`` debugging first. When you're done,
``character_system/examples/`` and the :ref:`recipes <doc_recipes>` show finished statuses,
items, zones and abilities to compare with yours, and :ref:`doc_extending` adds a melee
weapon, radius targeting, a hostility condition and example components on top.

Checklist
---------

- Stage 1: B starts after A arrives and stops when A leaves; the stat math gives 18;
  subscribers hear an event in priority order
- Stage 2: the capsule walks and jumps; a speed modifier doubles and restores its speed; a
  mana pool refuses what it can't pay and refills
- Stage 3: fire damage against 50% resistance takes 5 of 10; damage grows with a stat
- Stage 4: poison ticks, Wet removes and refuses Burning, Undead refuses Poison, the ward
  halves hits, shared passives wait for both holders; armour and a shield give the same result
  in either order; a stun stops the capsule
- Stage 5: shoot, reload from inventory, each weapon keeps its rounds when switching, dropping
  the held weapon draws the next, ring raises max health without healing, a blast hurts both
  dummies
- Stage 6: self-heal and area fireball work; cooldown blocks a second press and pauses with the
  game; a cost is only paid when the cast finishes
