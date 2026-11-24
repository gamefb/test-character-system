.. _doc_timing_and_animation:

Timing and animation
====================

Timing belongs to the rules, as numbers in the Inspector. An animation plays along and never decides when something happens, so a game with no animations behaves exactly as one with them, and a hit can't arrive late because a clip was slow.

A use of a weapon or an ability has up to three parts. All of them are optional, and all start at 0:

.. list-table::
   :header-rows: 1

   * - Part
     - On a weapon
     - On an ability
   * - **Wind-up**: from the press until it goes off
     - **Wind Up** on its :ref:`Trigger<class_Trigger>`
     - **Cast Time** on its :ref:`AbilityData<class_AbilityData>`
   * - **Live**: how long it stays dangerous
     - **Active** on its :ref:`MeleeSweep<class_MeleeSweep>`
     - None: its effects run once. What it launches or spawns can last.
   * - **Recovery**: until the next use
     - What is left of one over the **Fire Rate**
     - **Cooldown**

With everything at 0, a weapon fires in the frame of the press, as it always has.

.. _doc_wind_up:

Wind-up
-------

Set **Wind Up** on a weapon's :ref:`Trigger<class_Trigger>`, in seconds. Everything the trigger sets off then comes that long after the press: the ray of a :ref:`Hitscan<class_Hitscan>`, the swing of a :ref:`MeleeSweep<class_MeleeSweep>`, the projectile launched from **User Effects**. A sword's backswing and a bow's draw are the same number.

- **It can be cut short.** If the wielder is stunned, disarmed or killed before the shot, or puts the weapon away, nothing fires. A round taken from a :ref:`Magazine<class_Magazine>` at the press goes back.
- **The fire rate counts from the press.** A trigger doesn't start another shot while one is winding up, so the time between two shots is one over the fire rate or the wind-up, whichever is longer.
- **The shot lands on the frame nearest the moment.** At 60 frames a second, a wind-up of 0.2 is 12 frames.

An ability's wind-up is its cast time, described in :ref:`doc_abilities`.

.. _doc_live_swings:

Swings that stay live
---------------------

Set **Active** on a :ref:`MeleeSweep<class_MeleeSweep>`, in seconds. The swing then stays dangerous for that long after the shot instead of being checked once:

- **It follows the weapon.** The shape is checked every physics frame at wherever the item is now. In a hand that an animation moves, such as a ``BoneAttachment3D`` on the hand bone used as the weapon's socket, that is where the blade is.
- **A fast blade can't skip a target.** Each check covers the path the item took since the last one, going round the arc of a turn, not straight across it. A check is added for every quarter of a metre the shape moved.
- **Each character is hit once per swing**, however long it stays inside.
- **It can be cut short.** A stun or a death ends the swing at once.

.. source-file:: ../../character_system/character/items/melee_sweep.gd

.. _doc_weapon_events:

What the character hears
------------------------

The character's components and statuses hear each stage as an :ref:`event<doc_events>`. The context's ``origin`` is the item's :ref:`ItemData<class_ItemData>` or the :ref:`AbilityData<class_AbilityData>`.

.. list-table::
   :header-rows: 1

   * - Event
     - Sent when
     - ``duration``
   * - ``weapon_started``
     - A press is accepted, in the same frame
     - The wind-up, or 0
   * - ``weapon_fired``
     - The shot happens
     - The wind-up, or 0
   * - ``weapon_interrupted``
     - A wind-up is cut short
     - The wind-up
   * - ``ability_cast_started``
     - An ability with a cast time starts casting
     - The cast time
   * - ``ability_used``
     - An ability's effects run
     - 0
   * - ``ability_interrupted``
     - A cast is cut short
     - 0

These are ordinary events, so a status can react to them: a trigger on ``weapon_fired`` makes a passive that heals on every swing.

.. _doc_animator:

Playing animations
------------------

An :ref:`Animator<class_Animator>` on the character plays a clip when it hears an event. It is the only part of the system that touches animation, and leaving it out changes nothing else.

.. source-file:: ../../character_system/character/animation/animator.gd

1. Add an Animator beside the character's other components and set **Player** to its ``AnimationPlayer``.
2. Add rows to **Animations**: an event on the left, picked from the list, and a clip on the right. ``weapon_started`` to ``swing``, ``ability_cast_started`` to ``cast``, ``died`` to ``death``.
3. For one item or ability, add a colon and its id to the event: ``weapon_started:sword`` to ``heavy_swing``. That row wins over the plain one.

A row whose clip the player doesn't have is skipped, and the editor warns about it, about an event nothing sends, and about a missing player.

**Keeping a clip in step.** Put a marker named ``hit`` in the clip, at the moment the blade connects or the spell leaves the hand. The Animator then plays the clip faster or slower so that the marker lands on the shot. A clip whose marker is at 0.5 seconds, on a sword with a wind-up of 0.25, plays at double speed. Change the wind-up, or let a status change it, and the animation follows with nothing to re-time. A clip without the marker plays at its own speed, as does the clip of a weapon with no wind-up.

**With an AnimationTree.** The Animator drives an ``AnimationPlayer``. A character animated by a tree leaves it out and listens to the same events from the script that drives the tree:

.. code-block:: gdscript

    func _ready() -> void:
    	ComponentManager.of(owner).event(&"weapon_started").connect(_on_weapon_started)


    func _on_weapon_started(_ctx: EffectContext) -> void:
    	tree.set("parameters/Swing/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

**In the starter pack.** The sword winds up for a quarter of a second and its swing stays live for 0.15 seconds. In the test level the player has a ``swing`` clip that turns the hand, with the marker where the wind-up ends, and an Animator with one row for the sword.

The system has no combos, charged attacks or root motion. A status that roots the wielder for the length of a swing can be applied from the trigger's **User Effects**, which run at the shot.
