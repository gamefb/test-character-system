:allow_comments: False

Character System documentation
==============================

A component-driven character system for Godot 4.8: characters, equipment and
Baldur's Gate 3-style statuses built from small nodes and data you edit in the Inspector. A
player, a hostile AI and a friendly AI are the same scene with different components and data.
A rifle and a magic ring are built the same way.

The system has three layers, and the documentation follows them:

- :ref:`Core <toc-core>` is the rules everything else is built on: components, events, stats,
  pools and health, effects and statuses. It knows nothing about weapons or movement.
- The :ref:`Character framework <toc-character-framework>` is the scaffold for a character,
  built on the core: brains and input, the motor, items and equipment, abilities, hit
  detection, and timing for animations. It decides how things work, not what is in the game.
- The :ref:`Starter pack <toc-starter-pack>` is what a player sees and uses: particular
  statuses, items, abilities, ways of moving and characters, ready to copy and change.

Around them:

- :ref:`About <toc-about>` explains the idea behind the system and the rules it follows.
- :ref:`Getting started <toc-getting-started>` has a quick start that builds a small level, the
  recipes for everyday jobs, such as making a status, a weapon or a zone, and a guide to
  building the whole system yourself, one stage at a time.
- :ref:`Project <toc-project>` covers the folders and the tests.
- The :ref:`Class reference <doc_class_reference>` documents every class, generated from the
  ``##`` comments in the scripts. Godot shows the same text in its built-in help: press
  :kbd:`F1` in the editor and search for a class name.

Every page in the three layers shows the full source of what it describes.

New to the system? Read the :ref:`overview <doc_overview>`, build the
:ref:`quick start <doc_quick_start>` level, then try a few :ref:`recipes <doc_recipes>`. To
change these pages themselves, see :ref:`About this documentation <doc_this_documentation>`.

.. toctree::
   :hidden:
   :maxdepth: 1
   :caption: About
   :name: toc-about

   about/overview

.. toctree::
   :hidden:
   :maxdepth: 1
   :caption: Getting started
   :name: toc-getting-started

   getting_started/quick_start
   getting_started/recipes
   getting_started/build_from_scratch

.. toctree::
   :hidden:
   :maxdepth: 2
   :caption: Core
   :name: toc-core

   core/core_architecture
   core/stats_and_modifiers
   core/effects_and_statuses
   core/editor_warnings

.. toctree::
   :hidden:
   :maxdepth: 2
   :caption: Character framework
   :name: toc-character-framework

   character_framework/character_components
   character_framework/movement
   character_framework/equipment
   character_framework/timing_and_animation
   character_framework/building_blocks
   character_framework/application_sources
   character_framework/extending

.. toctree::
   :hidden:
   :maxdepth: 2
   :caption: Starter pack
   :name: toc-starter-pack

   starter_pack/statuses
   starter_pack/items
   starter_pack/abilities
   starter_pack/movement
   starter_pack/characters

.. toctree::
   :hidden:
   :maxdepth: 2
   :caption: Project
   :name: toc-project

   project/project_layout
   project/testing

.. toctree::
   :hidden:
   :maxdepth: 1
   :caption: Class reference
   :name: toc-class-ref

   classes/index

.. toctree::
   :hidden:
   :maxdepth: 1
   :caption: Contributing
   :name: toc-contributing

   about/this_documentation
