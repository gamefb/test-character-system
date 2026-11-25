.. _doc_quick_start:

Quick start
===========

This page builds a small level in two parts, with no code:

- **Part 1** makes a level to play in from what ships in ``character_system/starter_pack/``:
  a player with a rifle, and a training dummy to shoot. About fifteen minutes.
- **Part 2** adds things of your own to it: two statuses, a zone, and a weapon whose shots
  carry three effects and a condition. About twenty minutes.

``tests/test_quick_start.gd`` builds the same level step by step and checks every number on this page.

Part 1: A level to play in
--------------------------

1. Add the input actions
~~~~~~~~~~~~~~~~~~~~~~~~

Open Project > Project Settings > Input Map and add these actions, each with a key or button:

.. list-table::
   :header-rows: 1

   * - Action
     - Suggested input
     - Used for
   * - ``forward``, ``back``, ``left``, ``right``
     - W, S, A, D
     - Walking. :ref:`PlayerBrain<class_PlayerBrain>` needs all four.
   * - ``jump``
     - Space
     - Jumping
   * - ``primary``
     - Left mouse button
     - Firing
   * - ``reload``
     - R
     - Reloading
   * - ``next_weapon``
     - Q
     - Switching weapons, in Part 2

:ref:`PlayerBrain<class_PlayerBrain>` also passes on ``secondary``, ``interact`` and ``previous_weapon`` once you add them. Until then, the Output panel lists them as a reminder when the game starts.

2. Make the level
~~~~~~~~~~~~~~~~~

Create a new 3D scene, name its root Level, and save it. Add:

- a **DirectionalLight3D**, rotated to shine down at an angle;
- a **StaticBody3D** named Floor, with a **CollisionShape3D** holding a BoxShape3D of size
  40 × 1 × 40 at y = -0.5, and a **MeshInstance3D** holding a BoxMesh of the same size and
  position, so you can see it.

3. Make the player
~~~~~~~~~~~~~~~~~~

Add a **CharacterBody3D** named Player at the origin, and give it:

- a **CollisionShape3D** holding a CapsuleShape3D, at y = 1, so the player's feet are at its
  origin;
- a **Camera3D** at y = 1.6, for its eyes;
- under the Camera3D, a **Node3D** named Hand at (0.3, -0.2, -0.5). Weapons appear here and
  turn with the camera.

Then add these as children of Player, in any order: **ComponentManager**, **Health**, **Statuses**, **PlayerBrain**, **CharacterMotor**, **MouseLook**, **Inventory**, **Equipment** and **WeaponSwitch**. They are in the Create New Node window under their own names. PlayerBrain and MouseLook find the camera by themselves.

Add a **WalkMode** and an **AirMode** as children of CharacterMotor. They come from the starter pack, and they're the ways the player can move: walking and jumping on the floor, and falling, steering and double jumping in the air. The motor starts in WalkMode, and the two hand over to each other by themselves.

Set two things in the Inspector:

- **Equipment > Sockets:** add an entry with the key ``weapon`` and the value
  ``../Camera3D/Hand``. The key is the slot weapons go in, and the path starts from the
  Equipment node.
- **Inventory > Items:** add two elements, each a new ItemInstance. Set the first one's Data to
  ``starter_pack/items/rifle.tres``. Set the second one's Data to ``starter_pack/items/rifle_ammo.tres``
  and its Count to 30.

When the game starts, WeaponSwitch draws the rifle, because the hands are empty and the Inventory holds a weapon.

4. Add a training dummy
~~~~~~~~~~~~~~~~~~~~~~~

Add another **CharacterBody3D** named Dummy at (0, 0, -6), six metres in front of the player. Give it a **CollisionShape3D** holding a CapsuleShape3D at y = 1 and a **MeshInstance3D** holding a CapsuleMesh at y = 1, so you can see it. Then add a **ComponentManager**, a **Health** and a **Statuses**. That's all a target needs: no brain, no movement.

Add a **Nameplate** as a child of Dummy, at y = 2.4. It shows the dummy's name, health and statuses above its head, so you can watch what your shots do.

5. Play
~~~~~~~

Press F6 to run the scene. W, A, S and D walk, the mouse looks around, a left click fires and R reloads. Esc frees the mouse, and a click captures it again.

- **Shoot the dummy.** Each hit takes 10 health: the nameplate goes from 100 / 100 to
  90 / 100.
- **Empty the rifle.** It holds 12 rounds. R reloads from the 30 in the Inventory.

Part 2: Make it yours
---------------------

Everything in this part is a file you make in the editor and fill in the Inspector. Make two folders for them first: ``res://data/`` and ``res://scenes/``.

Two things you'll do several times:

- **Make a data file.** In the FileSystem dock, right-click the folder, choose Create New >
  Resource..., pick the type, and name the file. Double-click it to open it in the Inspector.
- **Add to a list.** Click the list in the Inspector to open it and press Add Element. For a
  list of names, type the name or pick it from the suggestions. For a list of effects,
  modifiers or conditions, click the new empty slot and choose the kind, such as New
  DamageEffect, then click it again to fill in its fields.

6. Your first status: Chilled
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

A status is anything a character can have for a while: a burn, a buff, a trait. This one halves the speed of whoever has it.

Make a **StatusData** file, ``data/chilled.tres``, and set:

.. list-table::
   :header-rows: 1

   * - Field
     - Value
     - What it does
   * - **ID**
     - ``chilled``
     - Its name in code and in saved data
   * - **Display Name**
     - Chilled
     - What nameplates and the HUD show
   * - **Tags**
     - ``cold``
     - What kind of status it is. Immunities and conditions look at tags, not at single
       statuses.
   * - **Modifiers**
     - A new StatModifier with **Stat** ``move_speed`` and **Mul** 0.5
     - Multiplies the walking speed by a half while the status is active

Leave **Duration** at 0. A status with no duration lasts for as long as something holds it on the character, which the next step does.

7. A zone that gives it: an ice patch
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Add an **EffectZone** named IcePatch as a child of Level, at (4, 0, 0). Give it a **CollisionShape3D** holding a BoxShape3D of size 3 × 2 × 3 at y = 1, and a **MeshInstance3D** holding a BoxMesh of size 3 × 0.04 × 3, so you can see where it is.

Set **Status While Inside** to ``data/chilled.tres``. The zone holds the status on every character standing in it and lets go when they leave.

8. A status that hurts: Frostbite
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The second status runs out by itself and does something every second. Make another **StatusData** file, ``data/frostbite.tres``:

.. list-table::
   :header-rows: 1

   * - Field
     - Value
     - What it does
   * - **ID**, **Display Name**
     - ``frostbite``, Frostbite
     -
   * - **Tags**
     - ``cold``
     - The same kind as Chilled
   * - **Duration**
     - 5
     - Seconds until it ends
   * - **Tick Interval**
     - 1
     - Seconds between ticks
   * - **On Tick**
     - A new DamageEffect with **Amount** 3 and **Type** ``cold``
     - What each tick does to the character that has it

A DamageEffect is your first *effect*: one thing that happens to a target. A status's On Tick list, a weapon's hit, a zone and an ability all take the same effects.

9. Your first weapon: a frost pistol
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

An item is two files: a scene that holds its parts, and a data file that names it and says which slot it goes in.

**The scene.** Create a new scene with a **Node3D** root named FrostPistol, and save it as ``scenes/frost_pistol.tscn``. Add as its children:

- a **MeshInstance3D** holding a BoxMesh of size 0.08 × 0.12 × 0.3, so there is something in
  the hand;
- a **ComponentManager**;
- a **Trigger**, with **Fire Rate** 2. It decides when the pistol fires: twice a second at
  most, on the ``primary`` action;
- a **Hitscan**. It decides what a shot reaches: the first thing on a straight line to the
  crosshair.

**The effects.** What a shot does to what it reaches is the Hitscan's **Effects** list. Add three, in this order:

.. list-table::
   :header-rows: 1

   * - Effect
     - Fields
     - What it does
   * - DamageEffect
     - **Amount** 6, **Type** ``cold``
     - Every shot does 6
   * - DamageEffect
     - **Amount** 10, **Type** ``cold``, and in **Conditions** a new HasTagCondition with
       **Tag** ``cold``
     - 10 more, but only if the target already has a ``cold`` status. A *condition* is a
       yes-or-no question that decides whether its effect runs.
   * - ApplyStatusEffect
     - **Status** ``data/frostbite.tres``
     - Gives the target Frostbite

The effects run in order. The first shot finds a target that isn't cold yet, so it does 6 and then makes it cold. Every shot after that does 16 for as long as the Frostbite lasts.

**The data.** Make an **ItemData** file, ``data/frost_pistol.tres``, with **ID** ``frost_pistol``, **Display Name** Frost pistol, **Slot** ``weapon`` and **Scene** ``scenes/frost_pistol.tscn``.

**Give it to the player.** In the level, select Player > Inventory and add a third element to **Items**: a new ItemInstance whose Data is ``data/frost_pistol.tres``. The pistol has no magazine, so it never runs out.

10. Play again
~~~~~~~~~~~~~~

Press F6.

- **Walk onto the ice patch.** You move at half speed while you stand on it, and at full speed
  again the moment you step off.
- **Press Q** to put the rifle away and draw the frost pistol.
- **Shoot the dummy once.** It loses 6, and the nameplate shows Frostbite under its health,
  which then drops by 3 every second for five seconds.
- **Shoot it again while it is cold.** Each of these shots takes 16.

What you built
~~~~~~~~~~~~~~

.. list-table::
   :header-rows: 1

   * - You made
     - Which is
     - More about it
   * - Chilled, Frostbite
     - Statuses: one held by a zone, one that runs out
     - :ref:`doc_status_data`, and the starter pack's :ref:`statuses <doc_example_statuses>`
   * - The ice patch
     - A zone
     - :ref:`doc_environment`
   * - The pistol's three entries, and Frostbite's tick
     - Effects
     - :ref:`doc_effects_statuses_and_passives`
   * - "Only if the target is cold"
     - A condition
     - :ref:`doc_conditions`
   * - The frost pistol
     - An item, from a Trigger and a Hitscan
     - :ref:`doc_equipment_system`

Things to try
~~~~~~~~~~~~~

Each of these changes one or two fields:

- **Make Frostbite stack.** In ``frostbite.tres``, set **Stacking** to Stack and
  **Max Stacks** to 3. Each shot now adds a stack, and each tick takes 3 for every stack:
  9 a second at three.
- **Make the dummy immune.** Make a third StatusData, ``data/thick_fur.tres``, with **ID**
  ``thick_fur``, **Display Name** Thick fur and **Immune To** ``cold``. Add it to
  Dummy > Statuses > **Innate**. The dummy now refuses Frostbite, so every shot does 6, and it
  would walk across the ice patch at full speed.
- **Give the pistol a magazine.** Add a **Magazine** to the pistol's scene and it holds 30
  rounds, which R reloads for free. Set its **Ammo** to an item, as the rifle's is, and
  reloading takes that item from the Inventory.

Next steps
----------

- :ref:`Recipes <doc_recipes>` make the dummy fight back, show health on screen, and build
  more statuses, items and abilities.
- :ref:`Extending the system <doc_extending>` covers writing your own components, effects and
  conditions, for when data isn't enough.
- :ref:`Core <toc-core>`, the :ref:`Character framework <toc-character-framework>` and the
  :ref:`Starter pack <toc-starter-pack>` explain each part of the system with its source code.
