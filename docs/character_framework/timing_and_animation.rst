.. _doc_timing_and_animation:

Timing and animation
====================

Timing belongs to the rules, as numbers in the Inspector. An animation plays along and never decides when something happens, so a game with no animations behaves exactly as one with them, and a hit can't arrive late because a clip was slow.

A use of a weapon or an ability has up to four parts. All of them are optional, and all start at 0:

.. list-table::
   :header-rows: 1

   * - Part
     - On a weapon
     - On an ability
   * - **Wind-up**: from the press until it goes off
     - **Wind Up** on its :ref:`Trigger<class_Trigger>`
     - **Cast Time** on its :ref:`AbilityData<class_AbilityData>`
   * - **Charge**: held for as long as the player likes, and fired by letting go
     - **Charge Time** on its :ref:`Trigger<class_Trigger>`, in place of the wind-up
     - None
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

Set **Wind Up** on a weapon's :ref:`Trigger<class_Trigger>`, in seconds. Everything the trigger sets off then comes that long after the press: the ray of a :ref:`Hitscan<class_Hitscan>`, the swing of a :ref:`MeleeSweep<class_MeleeSweep>`, the projectile launched from **User Effects**. A sword's backswing and a rocket launcher's spin-up are the same number.

- **It can be cut short.** If the wielder is stunned, disarmed or killed before the shot, or puts the weapon away, nothing fires. A round taken from a :ref:`Magazine<class_Magazine>` at the press goes back.
- **The fire rate counts from the press.** A trigger doesn't start another shot while one is winding up, so the time between two shots is one over the fire rate or the wind-up, whichever is longer.
- **The shot lands on the frame nearest the moment.** At 60 frames a second, a wind-up of 0.2 is 12 frames.

An ability's wind-up is its cast time, described in :ref:`doc_abilities`.

.. _doc_charging:

Charging
--------

Set **Charge Time** on a weapon's :ref:`Trigger<class_Trigger>`: the seconds of holding for a full charge. The press then starts the charge instead of firing, and letting go fires. How far the charge got is a number from 0 to 1, the shot's ``charge``.

- **A full charge can be held.** The charge stops at 1 and waits for the button to be let go.
- **Letting go too soon can cancel the shot.** **Min Charge** is the share of a full charge the shot needs. With 0.25, a quarter of the charge time must pass; with 1, only a full charge fires. Let go sooner and nothing fires, and the round goes back.
- **It can be cut short.** A stun, a disarm, a death or putting the weapon away cancels the charge, as it cancels a wind-up.
- **The wielder can have a status while charging.** Set **Status While Charging** to a status with duration 0, such as one that halves ``move_speed`` or drains stamina each second. It is dropped when the charge ends, however it ends.
- **The button can be held early.** A weapon that charges starts as soon as it can while the button is down, so a press made during the cooldown isn't lost. The cooldown counts from the shot, not from the press.
- **Wind Up isn't used.** On a weapon that charges, the hold is the wind-up.

**What a charge is worth is up to you.** The trigger only measures the charge. It goes into the context of everything the shot does, as ``charge``, and two building blocks read it there:

.. list-table::
   :header-rows: 1

   * - Want
     - Add
   * - A harder hit
     - A :ref:`ChargeAmount<class_ChargeAmount>` in the **Scaling** of the weapon's :ref:`DamageEffect<class_DamageEffect>`: 10 damage plus 20 at full
   * - A faster arrow
     - A ChargeAmount in the **Speed Scaling** of the :ref:`LaunchProjectileEffect<class_LaunchProjectileEffect>`
   * - A bigger shove
     - A ChargeAmount in the **Scaling** of a :ref:`KnockbackEffect<class_KnockbackEffect>`
   * - More of a pool spent, or more healing
     - A ChargeAmount in a :ref:`ChangePoolEffect<class_ChangePoolEffect>` or a :ref:`HealEffect<class_HealEffect>`
   * - Something that only a full charge does, such as bleeding or a stun
     - A :ref:`ChargeCondition<class_ChargeCondition>` in that effect's **Conditions**
   * - A reward that comes late in the draw
     - A **Curve** on the ChargeAmount that stays low and rises at the end
   * - Something a list can't reach, such as a tighter spread
     - An item component of your own that reads the trigger's ``charge``; see :ref:`doc_extending_item_component`

A charge that nothing reads changes nothing: the shot is the same at any charge. A projectile carries the charge of the weapon that launched it, so the amounts and conditions on the projectile's own effects see it too. A status that reacts to a hit sees the charge of that hit.

.. source-file:: ../../character_system/character/amounts/charge_amount.gd

.. source-file:: ../../character_system/character/conditions/charge_condition.gd

**Showing it.** ``Trigger.is_charging()`` is true while the charge builds and ``Trigger.charge`` is how far it has got. The example :ref:`CharacterHud<class_CharacterHud>` fills a ProgressBar named ChargeBar from them.

**For an AI.** An AI has to hold the button too. The example :ref:`AttackNearest<class_AttackNearest>` has a **Hold Time**: how long it keeps the button down before letting go.

**In the starter pack.** The longbow takes 0.8 seconds to draw and needs a quarter of that to loose. Its arrow does 8 damage and up to 22 more, flies up to 30 metres a second faster, and makes the target bleed only at a full draw. The archer moves at half speed while drawing.

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
     - A press is accepted, in the same frame: the wind-up or the charge begins
     - The wind-up, or the charge time, or 0
   * - ``weapon_fired``
     - The shot happens. Its ``charge`` is how far it was charged
     - 0
   * - ``weapon_interrupted``
     - A wind-up or a charge is cut short, or the button was let go under the minimum charge
     - 0
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

For a weapon that charges, the same marker lands on the full charge: a draw clip mapped to ``weapon_started`` reaches its ``hit`` marker when the bow is fully drawn and holds there, and a second row plays the release on ``weapon_fired``.

The system has no combos or root motion. A status that roots the wielder for the length of a swing can be applied from the trigger's **User Effects**, which run at the shot.
