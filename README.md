# Character System

A component-driven character system for Godot 4.8: characters, equipment, abilities
and Baldur's Gate 3-style statuses built from small nodes and data you edit in the Inspector.
Stats, mana and shields, damage that scales with a character, crits, costs and cast times,
projectiles and gear with bonuses need no code.

**Documentation:** https://gamefb.github.io/test-character-system/

New to it? Open `test_level/test_level.tscn` and press F6 to walk around a level with every
part in it, then follow the Quick start page, which builds a small level in about fifteen
minutes.

## What's here

| Folder | What it is |
| --- | --- |
| `character_system/core/` | The rules everything shares, in 22 scripts: components, stats, events, effects, pools, health and statuses. It loads on its own. |
| `character_system/character/` | The character framework: the scaffold a character and its gear are assembled on. Brains, the motor, abilities, inventory, weapon parts, zones, projectiles and timing for animations. Keep what you use. |
| `character_system/starter_pack/` | What a player sees and uses: statuses, items, abilities, zones, ways of moving and characters to copy. Start with `character_system/RECIPES.md`. |
| `addons/character_system_warnings/` | Editor plugin that warns about mistyped stat, event and tag names. |
| `tests/` | GUT unit tests (239 tests), and `benchmark.gd`. |
| `test_level/` | A playable level with every part of the system in it, and a self-test that plays it. |
| `immunity_test/` | A scripted scene that runs 43 checks on immunities, zones and items. |
| `docs/` | The documentation site (Sphinx). |

## Running the tests

The unit tests use [GUT](https://github.com/bitwes/Gut) 9.x, which isn't included. Install it
from the AssetLib tab, then:

```shell
godot --headless -s addons/gut/gut_cmdln.gd -gexit
godot --headless --fixed-fps 60 res://immunity_test/immunity_test.tscn
godot --headless --fixed-fps 60 res://test_level/test_level.tscn -- --self-test
```

GitHub Actions runs all three, the linter and a check that each layer loads without the ones built on it, on every
pull request (`.github/workflows/tests.yml`).

## Building the docs

```shell
pip install -r docs/requirements.txt   # also needs Graphviz for the diagrams
sphinx-build -b html docs docs/_build/html
```

Pushing to `main` publishes the site to GitHub Pages. To regenerate the class reference after
changing a `##` comment, see [About this documentation](docs/about/this_documentation.rst).
