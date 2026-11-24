.. _doc_core_architecture:

Core architecture
=================

A host is any node with a :ref:`ComponentManager<class_ComponentManager>` child and :ref:`Component<class_Component>` children: a ``CharacterBody3D`` character, a ``Node3D`` weapon or a ``RigidBody3D`` barrel alike. Components never hold references to each other. They register with the manager, look each other up through it when they need them, read shared numbers from it and hear events through it.

.. source-file:: ../../character_system/core/component.gd

How a component lives:

1. **Enters the tree:** it registers with the host's :ref:`ComponentManager<class_ComponentManager>`, and the numbers its ``_stats()`` returns become readable.
2. **Starts:** ``_start()`` runs once the host is ready and every type in ``_requires()`` is present. A component added mid-game starts straight away.
3. **Stops:** ``_stop()`` runs when it leaves, or when something it requires leaves. Connections made with ``listen()`` and events asked for with ``on()`` are undone.
4. **Restarts:** if what it required comes back, ``_start()`` runs again.

A component that can't start shows a yellow warning in the editor and reports it once in the Output panel; the rest of the character keeps working. Nothing runs in the editor: built-in components are ``@tool`` so they can show warnings, and the base class turns their processing off there and never calls ``_start()``. It does its work in ``_notification()``, which Godot calls for every script in the inheritance chain, so a component may still override ``_ready()`` without calling ``super()``.

.. list-table::
   :header-rows: 1

   * - Need
     - Use
     - Example
   * - Another component on the same host
     - ``find(Type)``
     - :ref:`CharacterMotor<class_CharacterMotor>` finds the :ref:`Brain<class_Brain>` in ``_start()``
   * - A plain node under the host, such as a camera
     - ``find_node_of_type(&"Camera3D")`` in ``_start()``
     - :ref:`PlayerBrain<class_PlayerBrain>` finds its camera when Camera is left empty
   * - A component on another node
     - ``Type.find_on(node)``, or ``Component.of(node, Type)`` for a type of your own
     - :ref:`DamageEffect<class_DamageEffect>` finds the target's :ref:`Health<class_Health>`
   * - React to another component's signal
     - ``listen(signal, method)`` in ``_start()``
     - :ref:`Health<class_Health>` listens to ``ComponentManager.stat_changed``
   * - Something that happened to the host
     - ``on(event, method)`` in ``_start()``
     - :ref:`Equipment<class_Equipment>` unequips what was dropped on ``inventory_changed``
   * - Something that happened to another host
     - ``on(event, method, node)`` in ``_start()``
     - An item component hearing its wielder's ``killed``
   * - Every event on the host
     - ``listen(manager.event_sent, method)`` in ``_start()``
     - :ref:`Statuses<class_Statuses>` passing events on to status triggers
   * - Something that happened to anyone
     - ``WorldEvents.event(name).connect(method)``
     - Experience for every enemy that dies
   * - Several components of one type
     - ``find_all(Type)``
     - A character's :ref:`Pool<class_Pool>`\ s; one is found by name with ``Pool.named()``
   * - A number statuses can change
     - ``_stats()`` to own it, ``stat()`` to read it
     - :ref:`CharacterMotor<class_CharacterMotor>` owns ``move_speed``, and :ref:`WalkMode<class_WalkMode>` reads it
   * - A number of your game's own, with no script
     - The manager's **Stats** in the Inspector
     - ``strength``, ``level``, ``crit_chance``

The manager is the hub. You add one per host and never change it; a new kind of component needs nothing from it.

.. source-file:: ../../character_system/core/component_manager.gd

The manager's third job is events. Each event is a Godot signal that ``event()`` hands out, so listening is ``connect()`` and a freed listener is dropped by the engine. ``send()`` emits ``event_sent``, which carries every event, then the event's own signal, and then passes it to :ref:`WorldEvents<class_WorldEvents>`, which hears every host. :ref:`doc_events` lists the events and the ways to hear them.

Lookups search the host's children, so ``find()`` and ``Component.of()`` also work on a scene that hasn't been added to the level yet. The manager remembers each answer until a child is added, removed or moved, so a lookup every frame costs about as much as reading a variable. ``Component.of()`` finds the manager by its name first, so keep the default name, ``ComponentManager``; a renamed one still works, it's just found by searching. Whether a component may start depends only on registered components, so one that is leaving no longer counts.
