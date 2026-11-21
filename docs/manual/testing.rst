.. _doc_testing:

Testing
=======

Unit tests catch broken combos (Wet stops putting out Burning, a ring stops granting its passive) before a player does. `GUT <https://github.com/bitwes/Gut>`__ is a free testing add-on, installed from the AssetLib tab inside Godot. A test file looks like this:

.. source-file:: ../../tests/test_statuses.gd

A test character is a plain ``Node3D`` with a :ref:`ComponentManager<class_ComponentManager>` and only the components the test needs, built in code with no scenes. The other test files:

.. list-table::
   :header-rows: 1

   * - File
     - Tests
     - What it checks
   * - ``test_core.gd``
     - 11
     - Components start in any order and once a requirement arrives, only process and get input while running, keep their own process mode, and stop and restart with a requirement; stats combine and update; events reach running components only; lookups work before the host is in the scene
   * - ``test_input.gd``
     - 9
     - Presses and releases, a release while paused or never seen, a press the UI used, two keys on one action, an AI press seen once by every node, automatic fire held and tapped
   * - ``test_player_brain.gd``
     - 2
     - Weapon actions are passed on; missing Input Map actions are skipped without errors
   * - ``test_inventory.gd``
     - 12
     - Weapon switching (drawing, wrapping around, holstering, dropping, each weapon's own rounds) and the carrying rule between Inventory and Equipment
   * - ``test_combat_parts.gd``
     - 5
     - Hitscan hits the target and not its wielder; cooldowns block reuse and wait while paused; teams are groups
   * - ``test_examples.gd``
     - 8
     - Every example loads and does what its name says: Burning, the traits, Wet, Warded, Thorns, the abilities and the items
   * - ``test_name_check.gd``
     - 12
     - Known names pass, typos are flagged with a guess, resources deep inside a status are checked, the examples are clean, the Inspector warning shows and hides
   * - ``test_lifecycle.gd``, ``test_combat.gd``, ``test_templates.gd`` (original project only)
     - 20
     - From the original project: the component lifecycle, combat and abilities, and the template scenes

GUT has no default test folder. In the GUT panel's settings, add ``res://tests/`` under Directories. For the command line, a ``.gutconfig.json`` file in the project root does the same:

.. source-file:: ../../.gutconfig.json
   :language: json

.. _doc_test_level:

Test level
----------

.. note::

   ``test_level/`` is in the original project but not in this repository yet.

The project also has a ``test_level/`` folder: a small arena built only from the system plus a few level scripts. Deleting the folder changes nothing else. It has a first-person player, two enemy spawners, one rifle used by the player, the enemies and the turrets, and a gadget that places turrets on the player's team.

It also shows the parts of a game this document leaves to you, as small scripts in ``test_level/scripts/``. ``combat_ai.gd`` is decision logic for :ref:`AIBrain<class_AIBrain>`: it picks the nearest hostile, sets ``target``, and holds ``primary`` in bursts while the target is in range and in sight. ``place_scene.gd`` is an item component that places a turret on the ground where the wielder aims. ``on_death.gd`` decides what death means: enemies and turrets are freed, and the player restarts the level.

.. list-table::
   :header-rows: 1

   * - Zone or item
     - What happens
     - Features used
   * - Fire patch
     - Entering applies Burning: 4 fire damage a second for 4 seconds
     - ``on_enter``, a timed status with ``on_tick``
   * - Water pool
     - Wet while inside: 40% slower, puts out Burning and blocks it
     - ``status_while_inside``, ``removes_tags``, ``immune_to``
   * - Healing pad
     - Regenerating while inside: heals 8 a second
     - ``status_while_inside``, ``on_tick``
   * - Ward circle
     - Warded while inside: every hit is halved, burn ticks included
     - status_while_inside, a taking_damage trigger with ModifyAmountEffect (× 0.5) and react_to_statuses
   * - Rifle
     - 5 extra damage to wet targets
     - A :ref:`DamageEffect<class_DamageEffect>` with a :ref:`HasTagCondition<class_HasTagCondition>`
   * - Turrets
     - Can't burn
     - A Construct trait in ``innate`` with ``immune_to`` = fire

The folder's README lists the controls and some things to try.

A second folder, ``immunity_test/``, is a scripted scene that runs 43 checks on immunities, zones and equipment together. Five characters walk their own track at once: a Knight who picks up a rifle, ammo, a flare gun and a fireproof cloak along the way and switches between the two guns, an Undead Ghoul, a Construct Golem, a Diver crossing water and fire, and a Cleric with a ward amulet. Press F6 on ``immunity_test.tscn`` to watch it, or run ``godot --headless --path . --fixed-fps 60 res://immunity_test/immunity_test.tscn``, which quits with exit code 0 when every check passes. Its README lists what each track shows.

.. _doc_verification_status:

Verification status
-------------------

All 70 tests and all 43 scene checks pass on both supported versions, last run on November 20: Godot 4.8 beta 3 with GUT 9.7.1 and Jolt physics, and Godot 4.4.1 with GUT 9.4.0. Every script in this document was rebuilt into a project and run headless on both.

.. list-table::
   :header-rows: 1

   * - Check
     - Godot 4.8 beta 3
     - Godot 4.4.1
   * - GUT tests (8 files above, test_statuses.gd included)
     - 70 of 70, 228 asserts
     - 70 of 70, 224 asserts
   * - ``immunity_test`` scene
     - 43 of 43
     - 43 of 43
   * - Code examples in ``RECIPES.md``
     - All compile
     - All compile

Breaking the system on purpose makes the tests fail. Each part of the input design fails its own test when undone: counting a press from code in the current frame, skipping the release check, forgetting a press when it's released, and dropping the extra physics frame. Earlier, with the 38-check version of the scene, ignoring ``immune_to`` failed 6 checks, ignoring ``removes_tags`` 1, ignoring ``react_to_statuses`` 1, and items that never drop their holds 3.

The scripts follow the GDScript style guide: a script that checks its main rules (code order, naming, static typing, line length, comments, one statement per line) reports nothing, and every link in the generated class reference resolves.

Some checks were made on the original project before the November 20 changes and not repeated, because their code isn't in this document. ``test_lifecycle.gd`` (10 tests), ``test_combat.gd`` (7) and ``test_templates.gd`` (3) passed. A headless editor run showed each editor warning where expected. The test level ran headless with scripted input for 32 checks and a 40-second fight with no errors. Mouse look hasn't been tested, because a headless run can't capture the mouse. ``ProjectileLauncher``, ``MeleeSweep`` and ``SpawnSceneEffect`` are described but not written.
