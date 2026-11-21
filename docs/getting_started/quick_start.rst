.. _doc_quick_start:

Quick start
===========

This page builds a small level in about fifteen minutes, with no code: a player with a rifle, a training dummy to shoot and a fire patch to walk into. Everything it uses ships in ``character_system/examples/``. ``tests/test_quick_start.gd`` builds the same level and checks it plays as described here.

1. Add the input actions
------------------------

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

:ref:`PlayerBrain<class_PlayerBrain>` also passes on ``secondary``, ``interact``, ``next_weapon`` and ``previous_weapon`` once you add them. Until then, the Output panel lists them as a reminder when the game starts.

2. Make the level
-----------------

Create a new 3D scene, name its root Level, and save it. Add:

- a **DirectionalLight3D**, rotated to shine down at an angle;
- a **StaticBody3D** named Floor, with a **CollisionShape3D** holding a BoxShape3D of size
  40 × 1 × 40 at y = -0.5, and a **MeshInstance3D** holding a BoxMesh of the same size and
  position, so you can see it.

3. Make the player
------------------

Add a **CharacterBody3D** named Player at the origin, and give it:

- a **CollisionShape3D** holding a CapsuleShape3D, at y = 1, so the player's feet are at its
  origin;
- a **Camera3D** at y = 1.6, for its eyes;
- under the Camera3D, a **Node3D** named Hand at (0.3, -0.2, -0.5). The rifle appears here and
  turns with the camera.

Then add these as children of Player, in any order: **ComponentManager**, **Health**, **Statuses**, **PlayerBrain**, **Movement**, **MouseLook**, **Inventory**, **Equipment** and **WeaponSwitch**. PlayerBrain and MouseLook find the camera by themselves.

Set two things in the Inspector:

- **Equipment > Sockets:** add an entry with the key ``weapon`` and the value
  ``../Camera3D/Hand``. The key is the slot the rifle goes in, and the path starts from the
  Equipment node.
- **Inventory > Items:** add two elements, each a new ItemInstance. Set the first one's Data to
  ``examples/items/rifle.tres``. Set the second one's Data to ``examples/items/rifle_ammo.tres``
  and its Count to 30.

When the game starts, WeaponSwitch draws the rifle, because the hands are empty and the Inventory holds a weapon.

4. Add a training dummy
-----------------------

Add another **CharacterBody3D** named Dummy at (0, 0, -6), six metres in front of the player. Give it a **CollisionShape3D** holding a CapsuleShape3D at y = 1 and a **MeshInstance3D** holding a CapsuleMesh at y = 1, so you can see it. Then add a **ComponentManager**, a **Health** and a **Statuses**. That's all a target needs: no brain, no movement.

5. Add a fire patch
-------------------

Drag ``character_system/examples/zones/fire_patch.tscn`` from the FileSystem dock into the scene, as a child of Level, and set its position to (4, 0, 0).

6. Play
-------

Press F6 to run the scene. W, A, S and D walk, the mouse looks around, a left click fires and R reloads. Esc frees the mouse, and a click captures it again.

- **Shoot the dummy.** Each hit takes 10 health, or 15 if the dummy is wet. To watch it, open
  the Remote tab at the top of the Scene dock while the game runs, select Dummy > Health and
  look at ``current`` in the Inspector.
- **Walk into the fire patch.** The player catches fire: Player > Statuses lists Burning under
  ``active``, and Health drops by 4 every second until it goes out.
- **Empty the rifle.** It holds 12 rounds. R reloads from the 30 in the Inventory.

Next steps
----------

- :ref:`Recipes <doc_recipes>` make the dummy fight back, show health on screen, and build your
  own statuses, items and abilities.
- :ref:`Extending the system <doc_extending>` covers writing your own components, effects and
  conditions.
- The :ref:`Manual <toc-manual>` explains each part of the system with its source code.
