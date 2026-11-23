# Character System

A component-driven character system for Godot 4.4 and later: characters, equipment, abilities
and Baldur's Gate 3-style statuses built from small nodes and data you edit in the Inspector.
Stats, mana and shields, damage that scales with a character, crits, costs and cast times,
projectiles and gear with bonuses need no code.

**Documentation:** https://gamefb.github.io/test-character-system/

New to it? Start with the Quick start page, which builds a small level in about fifteen minutes.

## What's here

| Folder | What it is |
| --- | --- |
| `character_system/` | The system: core, components, items, resources and examples. Start with `RECIPES.md`. |
| `addons/character_system_warnings/` | Editor plugin that warns about mistyped stat, event and tag names. |
| `tests/` | GUT unit tests (212 tests). |
| `immunity_test/` | A scripted scene that runs 43 checks on immunities, zones and items. |
| `docs/` | The documentation site (Sphinx). |

## Running the tests

The unit tests use [GUT](https://github.com/bitwes/Gut) 9.x, which isn't included. Install it
from the AssetLib tab, then:

```shell
godot --headless -s addons/gut/gut_cmdln.gd -gexit
godot --headless --fixed-fps 60 res://immunity_test/immunity_test.tscn
```

## Building the docs

```shell
pip install -r docs/requirements.txt   # also needs Graphviz for the diagrams
sphinx-build -b html docs docs/_build/html
```

Pushing to `main` publishes the site to GitHub Pages. To regenerate the class reference after
changing a `##` comment, see [About this documentation](docs/about/this_documentation.rst).
