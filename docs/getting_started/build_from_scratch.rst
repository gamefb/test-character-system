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

Four classes, no gameplay yet. When this stage works, components find each other, wait for what
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
     - The damage about to land. Statuses can change it before it does.
   * - ``from_status``
     - ``bool = false``
     - True when a status started this. Stops statuses from setting each other off forever.
   * - ``cause``
     - ``EffectContext``
     - Inside a status trigger, the context of the event that set it off, e.g. the hit a
       shield is reducing.
   * - ``_init(source, target, origin)``
     - constructor
     - All three optional.

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
   * - ``mul``
     - ``float = 1.0``
     - Multiplies the total.

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
   * - ``_modifiers``
     - var
     - ``Array[StatModifier]``.
   * - ``_cache``
     - var
     - ``Dictionary[StringName, float]`` of computed stats.
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
   * - ``has_registered(type)``
     - func
     - True if a registered component is that type.
   * - ``send(event, ctx)``
     - func
     - Calls ``_on_event`` on every *running* component.
   * - ``stat(name)``
     - func
     - ``(base + Σadd) × Πmul``, cached.
   * - ``add_modifier(m)`` / ``remove_modifier(m)``
     - func
     - Change the list, clear that stat's cache entry, emit ``stat_changed``.
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

    stat = (base + Σ add) × Π mul

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
   * - ``_connections``
     - var
     - Signal/callable pairs made with ``listen()``.
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
   * - ``listen(signal, callable)``
     - func
     - Connects and records it, so ``_halt()`` can undo it.
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
     - React to manager events.
   * - ``_warnings()``
     - virtual
     - Extra editor warnings, e.g. an export that must be set.
   * - ``_begin()`` / ``_halt()``
     - func
     - Called by the manager: flip ``running``, restore or disable ``process_mode``, call the
       virtual, and on halt disconnect everything from ``listen()``. ``_begin()`` also keeps
       what ``_requires()`` returned, for ``unregister``.

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

Test
~~~~

Make two dummy components where B requires A. Add A after B and check that B starts. Remove A
and check that B stops. Add a modifier with ``add = 2, mul = 1.5`` to a base of 10 and check you
get 18.

Stage 2: First real components
------------------------------

Seven components on top of the core give you a character that walks, has health and knows its
team. All extend ``Component``.

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
       ``max_health`` drops
   * - ``Brain``
     - ``move_dir``, ``aim_point``, ``_held``, ``_pressed_on``
     - ``press(action)``, ``release(action)``, ``is_action_pressed(action)``,
       ``is_action_just_pressed(action)``. It's the shared interface that the motor, Abilities
       and items read, the way your scripts read Godot's ``Input``.
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
     - ``motor`` and ``body``, set when entering the tree; a move's ``active`` and signals
       ``started``, ``finished``
     - Empty hooks ``_stats()``, ``_enter()``, ``_exit()`` and ``_physics_update(delta)``;
       ``stat()``; a mode's ``_can_enter()`` and ``_get_next_mode()``; a move's
       ``_can_start()``
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
- **Brains are swappable.** The motor only knows ``Brain``, so the same body works for a
  player or an AI. That's why it requires the base class, not ``PlayerBrain``.
- **One mode at a time, one use per press.** Only the current mode runs, and
  ``consume_action()`` remembers which presses were used this frame, so the press that jumps
  from the floor can't also spend an air jump, whatever order the nodes are in.
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
check the speed returns.

Stage 3: Effects and conditions
-------------------------------

Effects are ``Resource``\ s that do one thing to an ``EffectContext``. Conditions are
``Resource``\ s that answer yes or no. Because both are resources, you build abilities, statuses
and items in the Inspector instead of in code.

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
``StatCondition(stat, value)``.

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

Exports ``amount`` and ``type`` (e.g. ``physical``, ``fire``). It is the pipeline every damage
hook plugs into, and the order of its events is what makes shields, crits and thorns possible.

.. graphviz::
   :caption: The DamageEffect pipeline, and who hears each event.

   digraph damage {
       rankdir=TB;
       node [shape=box, style="rounded,filled", fillcolor="#e8f1fa", color="#3d8fcc", width=3.2];
       edge [color="#7a7a7a"];
       s1 [label="1. amount = amount × magnitude × (1 − resist)"];
       s2 [label="2. dealing_damage → source"];
       s3 [label="3. taking_damage → target"];
       s4 [label="4. health.change(−max(amount, 0))", fillcolor="#fbe9e7", color="#d9534f"];
       s5 [label="5. dealt_damage → source"];
       s6 [label="6. took_damage → target"];
       s1 -> s2 -> s3 -> s4 -> s5 -> s6;
   }

Events 2 and 3 run before the hit lands, so their statuses can still change ``ctx.amount``.
Events 5 and 6 run after, so their statuses can only react. The amount at step 1, where resist
is clamped to 0–1:

.. code-block:: text

    amount = amount × magnitude × (1 − resist_<type>)

Other effects
~~~~~~~~~~~~~

- ``HealEffect(amount)``: ``health.change(amount × magnitude)``.
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
   * - ``hit(source, collider)``
     - static
     - Builds the ``EffectContext``: resolves a hurtbox to its character and sets
       ``magnitude``.
   * - ``rids_of(character)``
     - static
     - The body and hurtbox RIDs, so a character's own shots ignore them. It searches the
       whole character, so weapons call it once, on equip.

Watch out for
~~~~~~~~~~~~~

- **Clamp the final amount at 0** before ``health.change``, or a big shield heals.
- **Effects must survive missing components.** ``Component.of(target, Health)`` can be null;
  return quietly.

Test
~~~~

A key that applies ``DamageEffect(10, "fire")`` to a dummy. Give the dummy
``resistances = {fire: 0.5}`` and check it loses 5.

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
     - e.g. ``taking_damage``, ``dealt_damage``, ``died``.
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
   * - ``has_tag(tag)``
     - func
     - True if any active status has the tag.
   * - ``is_immune_to(data)``
     - func
     - True if an active status's ``immune_to`` covers one of ``data``'s tags. ``add()``
       refuses those.
   * - ``_set_stacks(data, s, n)``
     - func
     - Adds or removes ``data.modifiers`` once per stack through ``manager.add_modifier``. This
       is how statuses change stats.
   * - ``_process(delta)``
     - func
     - Counts down durations; runs ``on_tick`` every ``tick_interval``. Only turned on (with
       ``set_process``) while a status has a duration or a tick interval.
   * - ``_on_event(event, ctx)``
     - func
     - On ``died``, ends timed statuses. Then, if ``ctx`` isn't null, runs the effects of each
       trigger whose event matches.
   * - ``_run(effects, data, s, target, cause)``
     - func
     - Builds a context with ``magnitude = stacks``, ``from_status = true``,
       ``cause = ctx``, then applies the effects.
   * - ``_stop()``
     - func
     - Removes everything, so modifiers come back off.

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
     - ``status``, ``drop_hold_only``
     - ``remove()``, or ``drop_hold()`` when ``drop_hold_only`` is set.
   * - ``ModifyAmountEffect``
     - ``add``, ``mul``
     - ``ctx.cause.amount = amount × mul + add``. Only does something inside a trigger.

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
  and forth forever.
- **Triggers need a context.** Events sent with a null ``ctx``, such as ``started`` and
  ``inventory_changed``, reach components but no status triggers.

Test
~~~~

Poison (duration 6, tick 1, ``DamageEffect`` 2 poison) ticks once a second until it ends. Wet
(``removes_tags: [burning]``) puts out Burning, and with ``immune_to: [fire]`` Burning can't
come back while it's wet. An Undead trait with ``immune_to: [poison]`` refuses Poison. A ward
(``taking_damage`` trigger, ``react_to_statuses``, ``ModifyAmountEffect`` ``mul 0.5``) halves
hits. A passive granted by a ring and a zone stays until both let go.

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
     - ``id``, ``display_name``, ``icon``, ``max_stack``, ``slot``, ``scene`` (the PackedScene
       equipped)
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
       change emits ``changed`` and sends the ``inventory_changed`` event.
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
     - ``action``, ``fire_rate``, ``automatic``, ``buffer_time``, ``_buffered``,
       ``_cooldown``; signal ``fired``
     - In ``_process``: buffer a press when ``brain.is_action_just_pressed(action)``; with
       ``automatic``, also want to fire while ``is_action_pressed``; when the cooldown is over,
       take a round from a ``Magazine`` if there is one, then emit ``fired``
   * - ``Magazine``
     - ``ammo: ItemData``, ``capacity``, ``rounds`` (stored in ``item.state``); signal
       ``changed(rounds)``
     - ``take() -> bool``, ``reload()`` pulling ammo from the wielder's Inventory; reload on
       ``is_action_just_pressed(&"reload")``
   * - ``Hitscan``
     - ``max_distance``, ``collision_mask``, ``effects``
     - ``_requires()`` returns ``[Trigger]``; ``_start()`` keeps ``Hurtbox.rids_of(wielder)``;
       on ``fired``, raycast toward ``brain.aim_point`` excluding those RIDs, build the context
       with ``Hurtbox.hit()``, then ``Effect.apply_all``
   * - ``GrantStatuses``
     - ``statuses``, ``_granted``
     - ``_start()``: add each status, keeping only those accepted; ``_stop()``: drop the hold
       of only those

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

Test
~~~~

Equip a rifle, shoot a dummy, empty the magazine and reload from the inventory. Pick up a second
weapon, switch to it and back, and check the rifle kept its rounds. Drop the held weapon and
check the other one is drawn. Equip a ring with a +20 ``max_health`` passive and check the
maximum rises without healing.

Stage 6: Abilities
------------------

Abilities reuse everything above: an ability is a cooldown, a way to pick targets, and a list of
effects.

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
     - ``id``, ``display_name``, ``icon``, ``cooldown``, ``targeting``, ``effects``
   * - ``Abilities``
     - ``Component``
     - ``slots: Dictionary[action, AbilityData]``,
       ``_cooldowns: Dictionary[AbilityData, SceneTreeTimer]``; ``_requires()`` returns
       ``[Brain]``; ``_process`` uses each slot whose action ``is_action_just_pressed``;
       ``use(ability) -> bool``; ``cooldown_left(ability) -> float``

``use(ability)`` in order:

1. Return false if ``cooldown_left(ability)`` is above 0. Otherwise start its cooldown with
   ``get_tree().create_timer(ability.cooldown, false)``, which stops while the game is paused.
2. Ask ``targeting.find()`` for targets, or use the host if there is no Targeting.
3. For each target, apply the effects with a fresh ``EffectContext(host, target, ability)``.

Test
~~~~

A heal on ``secondary`` that targets the user, and a fireball that applies ``DamageEffect`` plus
``ApplyStatusEffect(Burning)`` to everything in a sphere. Press twice quickly and check the
cooldown blocks the second use, and that pausing the game pauses the cooldown.

What to skip the first time
---------------------------

These were added late in the reference build and are easier once everything else works:

- **Editor support:** ``@tool``, ``_get_configuration_warnings``, and the ``is_tool()`` check
  needed because non-``@tool`` scripts are placeholders in the editor.
- **Name warnings:** :ref:`NameCheck <doc_editor_warnings_for_names>` and the Character System
  Warnings add-on, which catch mistyped stat, event and tag names.
- **Node icons** and ``##`` doc comments.
- **"Report missing once" error messages** in ``try_start``.

Get stages 1–3 running with plain ``print`` debugging first. When you're done,
``character_system/examples/`` and the :ref:`recipes <doc_recipes>` show finished statuses,
items, zones and abilities to compare with yours, and :ref:`doc_extending` adds a melee
weapon, radius targeting, a hostility condition and example components on top.

Checklist
---------

- Stage 1: B starts after A arrives and stops when A leaves; the stat math gives 18
- Stage 2: the capsule walks and jumps; a speed modifier doubles and restores its speed
- Stage 3: fire damage against 50% resistance takes 5 of 10
- Stage 4: poison ticks, Wet removes and refuses Burning, Undead refuses Poison, the ward
  halves hits, shared passives wait for both holders
- Stage 5: shoot, reload from inventory, each weapon keeps its rounds when switching, dropping
  the held weapon draws the next, ring raises max health without healing
- Stage 6: self-heal and area fireball work; cooldown blocks a second press and pauses with the
  game
