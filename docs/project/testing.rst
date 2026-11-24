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
     - 15
     - Components start in any order and once a requirement arrives, only process and get input while running, keep their own process mode, and stop and restart with a requirement (but keep running while another of its type is left); stats combine and update, and a new component reports its stats; events reach running components only; lookups work before the host is in the scene and follow components that come and go, and ``find_on()`` is safe on null, freed and plain nodes
   * - ``test_input.gd``
     - 9
     - Presses and releases, a release while paused or never seen, a press the UI used, two keys on one action, an AI press seen once by every node, automatic fire held and tapped
   * - ``test_player_brain.gd``
     - 6
     - Weapon actions and extra actions are passed on; a Camera left empty is found; missing Input Map actions are skipped without errors; the aim point is what the crosshair is on, never behind the weapon and never on an area a shot would pass through, and a camera behind the character doesn't aim at what is in between
   * - ``test_inventory.gd``
     - 12
     - Weapon switching (drawing, wrapping around, holstering, dropping, each weapon's own rounds) and the carrying rule between Inventory and Equipment
   * - ``test_motor.gd``
     - 14
     - A status that blocks movement stopping a dash and a jump, and one that blocks a mode's own name stopping that mode; the motor's events for jumps, landings and dashes, and a status trigger reacting to landing; a move's cooldown leaving its press for the next move; one floor jump plus one air jump, in either node order, and none with ``air_jumps`` at 0; the air jump comes back on take-off; walking at ``move_speed`` and statuses changing it; a dash on the floor and in the air, with its cooldown; a press used once; changing an action; knockback; modes removed and added during play; signals and switching modes from code; a mode outside a motor warns
   * - ``test_ai_brain.gd``
     - 1
     - The agent is found by itself, a new path is only asked for once the target has moved ``repath_distance``, and it aims ``aim_height`` above the target
   * - ``test_combat_parts.gd``
     - 9
     - Hitscan hits the target and not its wielder, and says which item dealt the hit; a weapon's projectile leaves from the weapon; shots and projectiles pass through plain areas, dead bodies and their hurtboxes, and stop at the living; cooldowns block reuse and wait while paused; teams are groups
   * - ``test_examples.gd``
     - 8
     - Every example loads and does what its name says: Burning, the traits, Wet, Warded, Thorns, the abilities and the items
   * - ``test_name_check.gd``
     - 15
     - Known names pass, including a pool's two stats and the ones listed in a manager's Stats; typos are flagged with a guess in stats, events, tags and pools, in amounts, ability costs, Blocked By lists and a status's Blocks too; resources deep inside a status are checked, the examples are clean, the Inspector warning shows and hides; name fields get a list to pick from, as plain names, array elements and dictionary keys, and every script with a name field is set up to show it
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
     - 13
     - The manager owning the stats listed on it; percentages adding up before multipliers; a conditional modifier following its condition, and one that reads its own stat; ``modifiers_of()`` naming what changes a stat; a Pool spending only what it has, regenerating after its delay, starting empty and fading, following its two stats, starting at its buffed maximum, and being found by name; health being a pool, with ``health_regen``, a health cost and the pool amount and condition; a pool giving a status while it is empty
   * - ``test_abilities.gd``
     - 15
     - Costs taken from a pool, and a missing pool; charges; ``cooldown_speed``; resetting a cooldown; conditions; a status blocking every ability, or only the ones that answer to a name of their own; a cast that takes time and pays at the end; damage and blocking statuses interrupting a cast; the status held while casting; needing a target; effects on the user; statuses reacting to ``ability_used``; a pressed action using its slot
   * - ``test_stun_and_death.gd``
     - 8
     - A status that blocks everything stops the brain and abilities; a dead character can't act until revived, a different death status decides what death stops, and with none nothing dies; the brain answering to the names it lists; blocks being counted, and set from code; death ending timed statuses and blocking healing; a status that blocks everything or movement stopping a walk; one that blocks weapons stopping a trigger; a stunned or dead wielder not firing
   * - ``test_events.gd``
     - 11
     - ``on()`` hearing one event until the component stops and again after a restart; listening to another host, and to one that is freed first; the fixed order in which listeners hear an event; an event being an ordinary signal, even one named like a signal of Node's; the connections of a freed listener, and of lambdas written in it, ending; WorldEvents hearing every host
   * - ``test_weapons.gd``
     - 12
     - The fire rate holding when frames don't divide into it; a reload that takes time; an empty magazine reloading itself; spread staying inside its angle; shotgun pellets each hitting; a projectile hitting what's in its way and not its launcher, with the hit point recorded; its own effects after the launcher's, even when the launcher has been freed meanwhile; a blast reaching everyone nearby, fading toward its edge, and going off when time runs out; a weapon launching one through its trigger's effects; an ability launching a projectile and getting the credit for the kill
   * - ``test_animation.gd``
     - 13
     - A rifle and an instant swing still landing in the frame of the press; a wind-up delaying the hit by its length, and being cancelled by a stun or by putting the weapon away, with the round returned; a live swing following the hand, hitting each character once, catching a target a fast blade would skip, and ending on a stun; the Animator starting a clip at the press and playing it so its marker lands on the hit, an item's own row winning, casts and deaths playing too, missing players and clips being skipped, and its editor warnings and event list
   * - ``test_items.gd``
     - 5
     - Gear changing stats while equipped and naming itself as the source; each copy carrying its own rolls; gear granting abilities and giving the slot back; a potion being used up; items that aren't used up, and ones that can't be used
   * - ``test_more_examples.gd``
     - 8
     - The newer examples do what their names say: Stunned and Silenced, Vampiric and Bloodlust, Fire ward, Sharpshooter, Lucky strikes, the ring, the staff and the shotgun, the health potion, and the mage casting a Fireball and losing its shield before its health
   * - ``test_extending.gd``
     - 13
     - The scripts on :ref:`doc_extending`: GlideMove slows the fall only while held and leaves the double jump alone, WallSlideMode takes over by itself and jumps off the wall, radius targeting finds enemies in range, the hostility condition spares allies, a spawned scene appears where the target is and goes after its lifetime, a melee swing hits only what's in front, Sprint spends from a pool while held, cleans up and stops when the pool is empty, Scope slows only while aiming, AttackNearest picks the nearest enemy and attacks it, an enemy built from it shoots the player, the HUD shows health, statuses and ammo, a weapon part of your own needs only ``_fire()``, and an effect of your own that extends AmountEffect gets the amount, the scaling and the magnitude
   * - ``test_quick_start.gd``
     - 1
     - The :ref:`quick start <doc_quick_start>` level, built as the page describes it, plays as promised

GUT has no default test folder. In the GUT panel's settings, add ``res://tests/`` under Directories. For the command line, a ``.gutconfig.json`` file in the project root does the same:

.. source-file:: ../../.gutconfig.json
   :language: json

The ``immunity_test/`` folder holds a scripted scene that runs 43 checks on immunities, zones and equipment together. Five characters walk their own track at once: a Knight who picks up a rifle, ammo, a flare gun and a fireproof cloak along the way and switches between the two guns, an Undead Ghoul, a Construct Golem, a Diver crossing water and fire, and a Cleric with a ward amulet. Press F6 on ``immunity_test.tscn`` to watch it, or run ``godot --headless --path . --fixed-fps 60 res://immunity_test/immunity_test.tscn``, which quits with exit code 0 when every check passes. Its README lists what each track shows.

.. _doc_test_level:

The test level
--------------

``test_level/test_level.tscn`` is a level to walk around in, with every part of the system in it. Open it and press F6. It is first person, and the keys are listed at the bottom of the screen.

.. list-table::
   :header-rows: 1

   * - Place
     - What it holds
   * - Armoury
     - Every example item as a pickup: seven weapons with their ammo, potions, grenades, a ring, a cloak and an amulet
   * - Targets
     - Dummies that show each hit as a number: plain, undead, construct, thorns, weak to fire, and the example mage with her shield. Heads count double
   * - Shrines
     - A pad for each passive, such as Sharpshooter, Vampiric and Executioner, and one that takes them away
   * - Hazards
     - The five example zones, and pads that stun, silence and root
   * - Arena
     - Two enemy soldiers and an ally with :ref:`AIBrain<class_AIBrain>`, on a navigation mesh
   * - Movement
     - A wall for the example :ref:`WallSlideMode<class_WallSlideMode>`, and a ledge to glide from

The characters, items and zones are set up in the Inspector from ``character_system/starter_pack/``. The level's one script does what a game does around them: it adds the input actions, equips what the player picks up, uses potions and grenades, draws the text on screen and brings the dead back.

Started with ``--self-test``, the level plays itself and prints 20 checks: the player is walked over every pickup, shrine and zone, then fires, casts, drinks and throws, and swings the sword, whose clip must start at the press and whose hit must land after the wind-up as the hand turns. One check is that a rifle held at the hip hits the head the crosshair is on. The first two checks are that the level uses every class and every example in ``character_system/``, so a new part can't be left out unnoticed.

.. code-block:: shell

   godot --headless --fixed-fps 60 res://test_level/test_level.tscn -- --self-test

.. _doc_ci:

Continuous integration
----------------------

``.github/workflows/tests.yml`` runs on every pull request and on every push to ``main``. It downloads the Godot build and the GUT version named at the top of the file, and then runs, in order: ``gdlint``; the layer check, which loads every script of ``core/`` with the other two folders deleted, and of ``core/`` and ``character/`` with ``starter_pack/`` deleted, using ``tests/check_scripts_load.gd``; the unit tests; the ``immunity_test`` scene; and the test level's self-test. A second workflow, ``docs.yml``, builds this documentation and fails on any warning.

.. _doc_performance:

Performance
-----------

``tests/benchmark.gd`` times the system with many characters; run it with ``godot --headless --fixed-fps 60 -s tests/benchmark.gd``. Each character has ten components and an equipped rifle, and walks across a floor. The numbers below are from Godot 4.8 beta 4 on a two-core virtual machine, the mean of three runs. They vary by 5 to 15% between runs and sessions, so measure on your own hardware before relying on them.

.. list-table::
   :header-rows: 1

   * - Measurement
     - Time
   * - 100 armed characters walking, per frame
     - 3.0 ms
   * - 300 armed characters walking, per frame
     - 9.2 ms
   * - ``find(Health)``
     - 0.5 µs
   * - ``Component.of(node, Health)``
     - 0.7 µs
   * - ``Health.find_on(node)``
     - 0.8 µs
   * - One damage hit
     - 17 µs
   * - A hit on a warded target with a thorns reply
     - 55 µs
   * - Freeing one character
     - about 100 µs

The base classes for effects with a number and for weapon parts, the typed ``find_on()`` lookups, and the wind-up, live swings and weapon events changed none of these beyond the difference between two runs of the same code. A weapon event that nothing listens to costs about 1.3 µs, and a shot sends two. A swing with an **Active** time costs about 14 µs for each check while it is live, and nothing the rest of the time. Against the version before health became a pool and statuses listed their blocks, measured in the same session, walking costs the same (within 1%) and a hit about 6% more: it passes through two more function calls on its way into the pool. Asking whether something is blocked is one dictionary look on the manager, which is why the brain and the motor can ask many times a frame, and an event nobody listens to costs about 0.3 µs.

.. _doc_verification_status:

Verification status
-------------------

All 239 tests and all 43 scene checks pass on Godot 4.8 beta 4 with GUT 9.7.1 and Jolt physics, run headless, last on November 23. Godot 4.8 is the baseline: ``@abstract`` needs 4.5, and nothing older is tested any more.

.. list-table::
   :header-rows: 1

   * - Check
     - Godot 4.8 beta 4
   * - GUT tests (24 files above, test_statuses.gd included)
     - 239 of 239, 1106 asserts
   * - ``immunity_test`` scene
     - 43 of 43
   * - Test level, ``--self-test``
     - 20 of 20
   * - ``core/`` on its own, with ``character/`` and ``starter_pack/`` deleted
     - All 22 scripts load
   * - ``core/`` and ``character/``, with ``starter_pack/`` deleted
     - All 64 scripts load
   * - Code examples in ``RECIPES.md``
     - All compile

Breaking the system on purpose makes the tests fail. Six changes were tried on the November 22 additions, and each failed at least one test: a :ref:`ModifyAmountEffect<class_ModifyAmountEffect>` that edits the amount in sequence, a Brain that is never blocked, a ``Statuses._stop()`` that runs ``on_remove``, a Trigger that throws away what a frame overshot the fire rate by, an ability that pays when its cast starts, and dead targets that still take hits. Each part of the input design fails its own test when undone: counting a press from code in the current frame, skipping the release check, forgetting a press when it's released, and dropping the extra physics frame. Earlier, with the 38-check version of the scene, ignoring ``immune_to`` failed 6 checks, ignoring ``removes_tags`` 1, ignoring ``react_to_statuses`` 1, and items that never drop their holds 3. Letting the motor's ``consume_action()`` hand out a press twice, or running every movement mode each frame instead of only the current one, makes ``test_motor.gd`` fail.

Timing was measured at a fixed 60 frames a second. A rifle and an instant swing land in the frame of the press, as before the wind-up was added; a wind-up of 0.2 seconds lands 12 frames after the press; and the Animator starts its clip in the frame of the press. The tests for this pass at real speed and at the fixed rate, and eleven deliberate breakages each failed one of them: checking a fast blade once a frame, hitting on every check, a swing that never stays live or doesn't end on a stun, a wind-up that is ignored, isn't cancelled by a stun or by putting the weapon away, or keeps the round, and an Animator that doesn't keep a clip in step, ignores an item's own row, or isn't told how long the wind-up is. The hand in these tests is a plain node turned by code or by an animation track. A skeleton with a ``BoneAttachment3D``, an ``AnimationTree``, and the Animator's table in the editor have not been tried.

The Inspector was looked at once, on November 23, by running the editor under a software renderer and taking screenshots: a status's Tags and Blocks, an ability's Costs and Blocked By and a modifier's Stat each showed a list of the project's names, and a :ref:`Health<class_Health>` node showed Death Status, Resistances, Max Value, Regen and Regen Delay with the other pool fields hidden. One list, a status's Blocks, was opened by a script and is the picture on :ref:`doc_name_lists`; for the others, a script run in editor mode printed what each list holds. Nobody has clicked through the Inspector by hand.

The scripts follow the GDScript style guide, and ``gdlint`` reports no problems. A script that checks the rules it doesn't (the order of methods and inner classes, continuation lines, trailing commas, numbers, quotes, comment spacing and backslash continuations) was run on November 23 against the guide as it stood on November 22. It found 28 deviations in the system's scripts and 17 in the tests and level scripts, all since fixed, and now reports none. It isn't part of the repository, and it can't judge what the guide leaves to the reader, such as whether an inferred type is clear. The documentation builds with no warnings, so every link in the generated class reference resolves.

Some checks were made on the original project before the November 20 changes and not repeated, because their code isn't in this document. ``test_lifecycle.gd`` (10 tests), ``test_combat.gd`` (7) and ``test_templates.gd`` (3) passed. A headless editor run showed each editor warning where expected. The test level ran headless with scripted input for 32 checks and a 40-second fight with no errors. Mouse look hasn't been tested, because a headless run can't capture the mouse. ``MeleeSweep`` and ``SpawnSceneEffect`` have since been written and are tested in ``test_extending.gd``, and the projectile launcher is written and tested in ``test_weapons.gd``.
