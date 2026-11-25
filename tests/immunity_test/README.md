# Immunity test

A scripted scene that checks immunities, zones and equipment together. Five characters walk
their own track at the same time, picking up items and crossing zones, and 43 checks run as
they go. Delete the folder and nothing else changes; it only uses `character_system/`.

## Run it

- **In the editor:** open `immunity_test.tscn` and press **F6**. The results list fills in at
  the top left; nameplates show each character's health and statuses. It takes about 18 seconds.
- **Headless:** `godot --headless --path . --fixed-fps 60 res://tests/immunity_test/immunity_test.tscn`
  finishes in about a second and quits with exit code 0 if every check passed, 1 if not.

## The tracks

| Track | Zones and pickups, in order | What it shows |
| --- | --- | --- |
| Knight | rifle, ammo, fire, healing pad, more ammo, flare gun, fireproof cloak, back through fire, shooting range | The first weapon picked up is drawn, the second only carried; a cloak in the bag does nothing until worn; worn, fire is refused; taken off, fire lands again; ammo stacks; reload pulls from the bag; the rifle does +5 to wet targets; next_weapon switches to the flare gun, which sets the dry dummy on fire but not the wet one; previous_weapon brings the rifle back with its rounds; dropping it draws the flare gun |
| Ghoul | poison bog, fire, healing pad | Undead trait (`immune_to: poison`): poison refused, fire still burns |
| Golem | fire, poison bog, ward circle | Construct trait (`immune_to: fire, poison`): both refused, but an untagged status like Warded still lands |
| Diver | water, fire, fire, water | Water gives Soaked (`immune_to: fire`, `removes_tags: fire`, 40% slower). Leaving gives Dripping for 3 s, so the next fire is refused; once dry it burns; the second pool puts the burning out |
| Cleric | ward amulet, fire, (equips amulet) fire, ward circle, poison bog | Burn ticks do 4 unwarded and 2 warded; amulet and circle each hold the ward; leaving the circle without the amulet ends it; no trait, so poison lands |

## Files

- `data/statuses/`: the nine statuses. Traits (Undead, Construct) and item passives (Fireproof,
  Warded) are statuses with duration 0 that use `immune_to`.
- `data/items/`, `scenes/items/`: rifle, flare gun, ammo, fireproof cloak, ward amulet. The
  Knight has a `WeaponSwitch`, so he can carry both guns and hold one.
- `scenes/zones/`: fire patch, water pool, healing pad, ward circle, poison bog. Reusable in
  other levels.
- `scripts/immunity_test.gd`: the scenario and its checks.
- `scripts/walker_brain.gd`: a Brain that walks to a point on cue, standing in for real AI.

The pickups come from `test_level/` (`scenes/item_pickup.tscn` and `item_pickup.gd`), so
this scene needs that folder, and the nameplates are the starter pack's `Nameplate`. The test level doesn't
need this one.
