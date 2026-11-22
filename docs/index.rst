:allow_comments: False

Character System documentation
==============================

A component-driven character system for Godot 4.4 and later: characters, equipment and
Baldur's Gate 3-style statuses built from small nodes and data you edit in the Inspector. A
player, a hostile AI and a friendly AI are the same scene with different components and data.
A rifle and a magic ring are built the same way.

The documentation is split into four parts:

- :ref:`About <toc-about>` explains the idea behind the system and the rules it follows.
- :ref:`Getting started <toc-getting-started>` has a quick start that builds a small level, the
  recipes for everyday jobs, such as making a status, a weapon or a zone, and a guide to
  building the whole system yourself, one stage at a time.
- The :ref:`Manual <toc-manual>` walks through every part of the system with its full source
  code, from the core to writing your own components and the test suite.
- The :ref:`Class reference <doc_class_reference>` documents every class, generated from the
  ``##`` comments in the scripts. Godot shows the same text in its built-in help: press
  :kbd:`F1` in the editor and search for a class name.

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
   :caption: Manual
   :name: toc-manual

   manual/core_architecture
   manual/stats_and_modifiers
   manual/effects_and_statuses
   manual/character_components
   manual/movement
   manual/equipment
   manual/character_archetypes
   manual/application_sources
   manual/extending
   manual/project_layout
   manual/editor_warnings
   manual/testing

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
