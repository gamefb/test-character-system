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
     - 14
     - Components start in any order and once a requirement arrives, only process and get input while running, keep their own process mode, and stop and restart with a requirement (but keep running while another of its type is left); stats combine and update, and a new component reports its stats; events reach running components only; lookups work before the host is in the scene and follow components that come and go
   * - ``test_input.gd``
     - 9
     - Presses and releases, a release while paused or never seen, a press the UI used, two keys on one action, an AI press seen once by every node, automatic fire held and tapped
   * - ``test_player_brain.gd``
     - 4
     - Weapon actions and extra actions are passed on; a Camera left empty is found; missing Input Map actions are skipped without errors
   * - ``test_inventory.gd``
     - 12
     - Weapon switching (drawing, wrapping around, holstering, dropping, each weapon's own rounds) and the carrying rule between Inventory and Equipment
   * - ``test_motor.gd``
     - 14
     - Statuses stopping a dash and a mode through Blocked By Tags; the motor's events for jumps, landings and dashes, and a status trigger reacting to landing; a move's cooldown leaving its press for the next move; one floor jump plus one air jump, in either node order, and none with ``air_jumps`` at 0; the air jump comes back on take-off; walking at ``move_speed`` and statuses changing it; a dash on the floor and in the air, with its cooldown; a press used once; changing an action; knockback; modes removed and added during play; signals and switching modes from code; a mode outside a motor warns
   * - ``test_ai_brain.gd``
     - 1
     - The agent is found by itself, a new path is only asked for once the target has moved ``repath_distance``, and it aims ``aim_height`` above the target
   * - ``test_combat_parts.gd``
     - 6
     - Hitscan hits the target and not its wielder, and says which item dealt the hit; cooldowns block reuse and wait while paused; teams are groups
   * - ``test_examples.gd``
     - 8
     - Every example loads and does what its name says: Burning, the traits, Wet, Warded, Thorns, the abilities and the items
   * - ``test_name_check.gd``
     - 12
     - Known names pass, typos are flagged with a guess, resources deep inside a status are checked, the examples are clean, the Inspector warning shows and hides
   * - ``test_extending.gd``
     - 11
     - The scripts on :ref:`doc_extending`: GlideMove slows the fall only while held and leaves the double jump alone, WallSlideMode takes over by itself and jumps off the wall, radius targeting finds enemies in range, the hostility condition spares allies, a spawned scene appears where the target is and goes after its lifetime, a melee swing hits only what's in front, Stamina speeds up while held and cleans up, Scope slows only while aiming, AttackNearest picks the nearest enemy and attacks it, an enemy built from it shoots the player, and the HUD shows health, statuses and ammo
   * - ``test_quick_start.gd``
     - 1
     - The :ref:`quick start <doc_quick_start>` level, built as the page describes it, plays as promised

GUT has no default test folder. In the GUT panel's settings, add ``res://tests/`` under Directories. For the command line, a ``.gutconfig.json`` file in the project root does the same:

.. source-file:: ../../.gutconfig.json
   :language: json

The ``immunity_test/`` folder holds a scripted scene that runs 43 checks on immunities, zones and equipment together. Five characters walk their own track at once: a Knight who picks up a rifle, ammo, a flare gun and a fireproof cloak along the way and switches between the two guns, an Undead Ghoul, a Construct Golem, a Diver crossing water and fire, and a Cleric with a ward amulet. Press F6 on ``immunity_test.tscn`` to watch it, or run ``godot --headless --path . --fixed-fps 60 res://immunity_test/immunity_test.tscn``, which quits with exit code 0 when every check passes. Its README lists what each track shows.

.. _doc_verification_status:

Verification status
-------------------

All 105 tests and all 43 scene checks pass on both supported versions, last run on November 22: Godot 4.8 beta 3 with GUT 9.7.1 and Jolt physics, and Godot 4.4.1 with GUT 9.4.0. Every script in this document was rebuilt into a project and run headless on both.

.. list-table::
   :header-rows: 1

   * - Check
     - Godot 4.8 beta 3
     - Godot 4.4.1
   * - GUT tests (12 files above, test_statuses.gd included)
     - 105 of 105, 365 asserts
     - 105 of 105, 361 asserts
   * - ``immunity_test`` scene
     - 43 of 43
     - 43 of 43
   * - Code examples in ``RECIPES.md``
     - All compile
     - All compile

Breaking the system on purpose makes the tests fail. Each part of the input design fails its own test when undone: counting a press from code in the current frame, skipping the release check, forgetting a press when it's released, and dropping the extra physics frame. Earlier, with the 38-check version of the scene, ignoring ``immune_to`` failed 6 checks, ignoring ``removes_tags`` 1, ignoring ``react_to_statuses`` 1, and items that never drop their holds 3. Letting the motor's ``consume_action()`` hand out a press twice, or running every movement mode each frame instead of only the current one, makes ``test_motor.gd`` fail.

The scripts follow the GDScript style guide. ``gdlint`` reports no problems, and a script that checks the rules it doesn't (the order of methods, continuation lines, trailing commas, numbers, quotes and comment spacing) reports nothing either. Every link in the generated class reference resolves.

Some checks were made on the original project before the November 20 changes and not repeated, because their code isn't in this document. ``test_lifecycle.gd`` (10 tests), ``test_combat.gd`` (7) and ``test_templates.gd`` (3) passed. A headless editor run showed each editor warning where expected. The test level ran headless with scripted input for 32 checks and a 40-second fight with no errors. Mouse look hasn't been tested, because a headless run can't capture the mouse. ``MeleeSweep`` and ``SpawnSceneEffect`` have since been written and are tested in ``test_extending.gd``; a projectile launcher is described in :ref:`doc_extending_item_component` but not written.
