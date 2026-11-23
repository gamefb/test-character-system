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
     - 13
     - Known names pass, including a pool's two stats and the ones listed on an Attributes component; typos are flagged with a guess in stats, events, tags and pools, in amounts, ability costs and Blocked By Tags too; resources deep inside a status are checked, the examples are clean, the Inspector warning shows and hides
   * - ``test_damage_pipeline.gd``
     - 13
     - Armour and a shield give the same result in either order; percentages add up and multipliers multiply; a modifier can count every stack; the hit reports what landed; the source's ``bonus_<type>`` and the target's resistance and weakness; a ward against one damage type; hurtbox tags reaching triggers and crits being labelled; a trigger's conditions checked once; a Pool soaking up damage, for all types or some; listeners that still edit the amount directly
   * - ``test_kills_and_healing.gd``
     - 9
     - A dead target takes no more hits and sends no events; the killer hears ``killed``, but not for killing itself; ``revived``; statuses changing healing given and received; triggers that set each other off are cut short; ``on_remove`` runs when a status ends and not when its character is freed; a status keeps ticking after whoever applied it is freed; removing statuses by tag
   * - ``test_conditions_and_effects.gd``
     - 6
     - Chance from never to always, and a stat adding to it; AnyCondition needing only one; the hit conditions reading the hit inside and outside a trigger; a scene spawning at the target, the hit point or the source; the lookups accepting a node that was just freed
   * - ``test_amounts.gd``
     - 10
     - Damage growing with the user's stat, with modifiers included; a curve by level; shares of current, missing and maximum health; life steal and thorns as a share of the hit; a status tick scaling with whoever applied it; random ranges; a pool effect scaling too
   * - ``test_stats_and_pools.gd``
     - 11
     - Attributes owning the stats listed on them; percentages adding up before multipliers; a conditional modifier following its condition, and one that reads its own stat; ``modifiers_of()`` naming what changes a stat; a Pool spending only what it has, regenerating after its delay, starting empty and fading, following its two stats, starting at its buffed maximum, and being found by name
   * - ``test_abilities.gd``
     - 15
     - Costs taken from a pool, and a missing pool; charges; ``cooldown_speed``; resetting a cooldown; conditions; a blocking status tag; a cast that takes time and pays at the end; damage and blocking statuses interrupting a cast; the status held while casting; needing a target; effects on the user; statuses reacting to ``ability_used``; a pressed action using its slot
   * - ``test_stun_and_death.gd``
     - 6
     - A stunned character reports no intent and can't use abilities; a dead one can't act until revived, unless told to carry on; the brain stopping on other tags; a stun stopping a walk; a tag stopping one weapon's trigger; a stunned or dead wielder not firing
   * - ``test_events.gd``
     - 11
     - ``on()`` hearing one event until the component stops and again after a restart; listening to another host, and to one that is freed first; priorities deciding the order; subscribing from outside; freed subscribers, and lambdas written in a freed object, being dropped; a listener counting as alive only while its object is; WorldEvents hearing every host
   * - ``test_weapons.gd``
     - 12
     - The fire rate holding when frames don't divide into it; a reload that takes time; an empty magazine reloading itself; spread staying inside its angle; shotgun pellets each hitting; a projectile hitting what's in its way and not its launcher, with the hit point recorded; its own effects after the launcher's, even when the launcher has been freed meanwhile; a blast reaching everyone nearby, fading toward its edge, and going off when time runs out; a Launcher on a weapon; an ability launching a projectile and getting the credit for the kill
   * - ``test_items.gd``
     - 5
     - Gear changing stats while equipped and naming itself as the source; each copy carrying its own rolls; gear granting abilities and giving the slot back; a potion being used up; items that aren't used up, and ones that can't be used
   * - ``test_more_examples.gd``
     - 8
     - The newer examples do what their names say: Stunned and Silenced, Vampiric and Bloodlust, Fire ward, Sharpshooter, Lucky strikes, the ring, the staff and the shotgun, the health potion, and the mage casting a Fireball and losing its shield before its health
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

All 212 tests and all 43 scene checks pass on both supported versions, last run on November 22: Godot 4.8 beta 3 with GUT 9.7.1 and Jolt physics, and Godot 4.4.1 with GUT 9.4.0. The project was run headless on both.

.. list-table::
   :header-rows: 1

   * - Check
     - Godot 4.8 beta 3
     - Godot 4.4.1
   * - GUT tests (23 files above, test_statuses.gd included)
     - 212 of 212, 909 asserts
     - 212 of 212, 905 asserts
   * - ``immunity_test`` scene
     - 43 of 43
     - 43 of 43
   * - Code examples in ``RECIPES.md``
     - All compile
     - All compile

Breaking the system on purpose makes the tests fail. Six changes were tried on the November 22 additions, and each failed at least one test: a :ref:`ModifyAmountEffect<class_ModifyAmountEffect>` that edits the amount in sequence, a Brain that is never blocked, a ``Statuses._stop()`` that runs ``on_remove``, a Trigger that throws away what a frame overshot the fire rate by, an ability that pays when its cast starts, and dead targets that still take hits. Each part of the input design fails its own test when undone: counting a press from code in the current frame, skipping the release check, forgetting a press when it's released, and dropping the extra physics frame. Earlier, with the 38-check version of the scene, ignoring ``immune_to`` failed 6 checks, ignoring ``removes_tags`` 1, ignoring ``react_to_statuses`` 1, and items that never drop their holds 3. Letting the motor's ``consume_action()`` hand out a press twice, or running every movement mode each frame instead of only the current one, makes ``test_motor.gd`` fail.

The scripts follow the GDScript style guide, and ``gdlint`` reports no problems. A script that checks the rules it doesn't (the order of methods, continuation lines, trailing commas, numbers, quotes and comment spacing) reported nothing on the project as it stood before the November 22 additions; it isn't part of the repository and hasn't been run on them. The documentation builds with no warnings, so every link in the generated class reference resolves.

Some checks were made on the original project before the November 20 changes and not repeated, because their code isn't in this document. ``test_lifecycle.gd`` (10 tests), ``test_combat.gd`` (7) and ``test_templates.gd`` (3) passed. A headless editor run showed each editor warning where expected. The test level ran headless with scripted input for 32 checks and a 40-second fight with no errors. Mouse look hasn't been tested, because a headless run can't capture the mouse. ``MeleeSweep`` and ``SpawnSceneEffect`` have since been written and are tested in ``test_extending.gd``, and the projectile launcher is written and tested in ``test_weapons.gd``.
