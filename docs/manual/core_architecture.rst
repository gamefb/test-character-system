.. _doc_core_architecture:

Core architecture
=================

A host is any node with a :ref:`ComponentManager<class_ComponentManager>` child and :ref:`Component<class_Component>` children: a ``CharacterBody3D`` character, a ``Node3D`` weapon or a ``RigidBody3D`` barrel alike. Components never hold references to each other. They register with the manager, look each other up through it when they need them, read shared numbers from it and hear events through it.

.. source-file:: ../../character_system/core/_base/component.gd

How a component lives:

1. **Enters the tree:** it registers with the host's :ref:`ComponentManager<class_ComponentManager>`, and the numbers its ``_stats()`` returns become readable.
2. **Starts:** ``_start()`` runs once the host is ready and every type in ``_requires()`` is present. A component added mid-game starts straight away.
3. **Stops:** ``_stop()`` runs when it leaves, or when something it requires leaves. Connections made with ``listen()`` are undone.
4. **Restarts:** if what it required comes back, ``_start()`` runs again.

A component that can't start shows a yellow warning in the editor and reports it once in the Output panel; the rest of the character keeps working. Nothing runs in the editor: built-in components are ``@tool`` so they can show warnings, and the base class turns their processing off there and never calls ``_start()``. It does its work in ``_notification()``, which Godot calls for every script in the inheritance chain, so a component may still override ``_ready()`` without calling ``super()``.

.. list-table::
   :header-rows: 1

   * - Need
     - Use
     - Example
   * - Another component on the same host
     - ``find(Type)``
     - :ref:`Movement<class_Movement>` finds the :ref:`Brain<class_Brain>` each frame
   * - A plain node under the host, such as a camera
     - ``find_node_of_type(&"Camera3D")`` in ``_start()``
     - :ref:`PlayerBrain<class_PlayerBrain>` finds its camera when Camera is left empty
   * - A component on another node
     - ``Component.of(node, Type)``
     - :ref:`DamageEffect<class_DamageEffect>` finds the target's :ref:`Health<class_Health>`
   * - React to another component's signal
     - ``listen(signal, method)`` in ``_start()``
     - :ref:`Health<class_Health>` listens to ``ComponentManager.stat_changed``
   * - Something that happened to the host
     - ``_on_event(event, ctx)``
     - :ref:`Statuses<class_Statuses>` clears timed statuses on ``died``
   * - A number statuses can change
     - ``_stats()`` to own it, ``stat()`` to read it
     - :ref:`Movement<class_Movement>` owns and reads ``move_speed``

The manager is the hub. You add one per host and never change it; a new kind of component needs nothing from it.

.. source-file:: ../../character_system/core/component_manager.gd

Lookups search the host's children, so ``find()`` and ``Component.of()`` also work on a scene that hasn't been added to the level yet. The manager remembers each answer until a child is added, removed or moved, so a lookup every frame costs about as much as reading a variable. ``Component.of()`` finds the manager by its name first, so keep the default name, ``ComponentManager``; a renamed one still works, it's just found by searching. Whether a component may start depends only on registered components, so one that is leaving no longer counts.
