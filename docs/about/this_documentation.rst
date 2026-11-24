.. _doc_this_documentation:

About this documentation
========================

This site is built with `Sphinx <https://www.sphinx-doc.org>`__ and the Read the Docs theme,
styled like the `Godot Engine documentation <https://docs.godotengine.org>`__. Its source is
the ``docs/`` folder of the project. ``docs/`` contains a ``.gdignore`` file, so Godot doesn't
import anything in it.

Where each part comes from
--------------------------

- **Code listings** on the pages are read from the project's files when the site is built, so
  they always match the code.
- **The class reference** is generated from the ``##`` comments in the scripts, with Godot's own
  converter. Change a comment, regenerate, and the page follows.
- **The recipes** page is ``character_system/RECIPES.md``, the same file you can read inside the
  project.
- **Everything else** is written in reStructuredText, in one folder for each part of the site:
  ``docs/about/``, ``docs/getting_started/``, ``docs/core/``, ``docs/character_framework/``,
  ``docs/starter_pack/`` and ``docs/project/``.

Building the site
-----------------

You need Python 3.10 or later and `Graphviz <https://graphviz.org>`__ for the diagrams. From
the project folder:

.. code-block:: shell

    pip install -r docs/requirements.txt
    sphinx-build -b html docs docs/_build/html

Open ``docs/_build/html/index.html`` in a browser. Pushing to the ``main`` branch on GitHub
builds the site with the workflow in ``.github/workflows/docs.yml``.

Updating the class reference
----------------------------

Run this after changing a ``##`` comment, or adding or renaming a class. Use the Godot version
you work with, and run it from the project folder:

.. code-block:: shell

    godot --headless --import
    godot --headless --doctool /tmp/engine_xml
    godot --headless --doctool /tmp/project_xml --gdscript-docs res://character_system
    python3 docs/tools/make_classref.py /tmp/engine_xml /tmp/project_xml

The second command writes the class reference of Godot itself, which the converter needs to
resolve types such as ``Node``. The third writes one XML file per ``class_name`` script. The
script then rewrites ``docs/classes/``. It also prints any notes from Godot's doc checker, such
as a ``[code]`` tag that could be a link.

Links to Godot's own classes, such as ``Node`` or ``CharacterBody3D``, point at the
`Godot class reference <https://docs.godotengine.org/en/stable/classes/index.html>`__.

Writing doc comments
--------------------

The class reference reads the comments the way Godot's built-in help does. The
`GDScript documentation comments <https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_documentation_comments.html>`__
page lists the tags. The ones used most here:

- ``[Health]`` links to a class, ``[member max_health]``, ``[method change]`` and
  ``[signal died]`` to its members.
- ``[code]...[/code]`` for inline code, ``[codeblock]...[/codeblock]`` for examples.
- ``[b]...[/b]`` for bold and ``[br]`` for a line break.

Private members (names starting with ``_``) appear only when they have a ``##`` comment, which
is how the methods you override, such as ``Component._start()``, get their pages.
