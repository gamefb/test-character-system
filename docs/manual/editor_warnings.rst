.. _doc_editor_warnings_for_names:

Editor warnings for names
=========================

Stats, events and tags are typed as text, so a typo such as ``move_sped`` or ``took_damgae`` would otherwise do nothing, with no error. :ref:`NameCheck<class_NameCheck>` reads the project for the names that exist: the stats components declare in ``_stats()`` (plus any ``resist_<type>``), the events scripts send with ``notify()`` or ``send()``, and the tags saved statuses have. Each name in your data is checked against them, and an unknown one gets a warning with the closest match, such as "Did you mean 'move_speed'?".

The warnings show in two places. :ref:`Statuses<class_Statuses>`, :ref:`GrantStatuses<class_GrantStatuses>`, :ref:`Abilities<class_Abilities>` and :ref:`Hitscan<class_Hitscan>` list them as node warnings in the Scene dock. The Character System Warnings add-on, enabled in Project Settings > Plugins, shows them above the Inspector for the resource being edited. Your own components can do the same by returning ``NameCheck.problems_in(...)`` from ``_warnings()``.

.. source-file:: ../../character_system/core/name_check.gd

It only sees names written in code and saved files. A name built at runtime, such as an event sent with a variable, isn't seen, so a trigger for it is reported even though it works. Resources saved in their own file are checked when you open them. With the add-on enabled, the project is read again whenever its files change or a resource is saved, so a large project isn't re-read while nothing changes. Without the add-on, it's read again at most every 30 seconds.
