# Test level

A level you can walk around in, with every part of the character system in it. Open
`test_level.tscn` and press **F6**.

It is built the way a game would be: the characters, items, zones and statuses are nodes and
resources set up in the Inspector, taken from `character_system/starter_pack/`. The only script,
`test_level.gd`, does what a game does around them: it adds the input actions, equips what the
player picks up, uses potions and grenades, draws the text on screen and brings the dead back.

## Controls

| Key | Action |
| --- | --- |
| W A S D, mouse | Move and look. Esc frees the mouse; click to take it back. |
| Space | Jump. Again in the air for a double jump; hold while falling to glide. |
| Shift, F | Sprint (spends the stamina pool), dash. |
| Left mouse | Fire or swing. |
| Right mouse | Zoom with the marksman rifle; cast Fireball with the fire staff. |
| R, E, Q | Reload, next weapon, previous weapon. |
| 1, 2, 3, 4 | Second wind, Sprint, Fireball, Shockwave. |
| H, J, G | Health potion, mana potion, throw a grenade. |

## What's in it

| Place | What to try |
| --- | --- |
| **Armoury**, straight ahead | Walk over an item to pick it up. Rifle, shotgun, flare gun, marksman rifle (scope), rocket launcher, fire staff (grants Fireball) and sword (melee), with their ammo; potions and grenades; a ring (+25 health), a cloak (fire immunity) and an amulet (ward), which are put on at once. |
| **Targets**, behind the armoury | Dummies that show each hit as a number and stand back up after 4 seconds. One is plain, one undead (immune to poison), one a construct (immune to fire and poison), one has thorns, one is weak to fire and tough against bullets, and the mage has a shield that soaks up damage first. Heads count double. |
| **Shrines**, on the left | Step on a pad for its passive: Sharpshooter, Lucky strikes, Vampiric, Bloodlust, Thorns, Fire ward, Regenerating, Haste, Executioner, Berserk. The white pad takes them all away. |
| **Hazards**, on the right | The example zones (fire, water, healing, ward, poison) and pads that stun, silence and root you. Each is a status that lists what it blocks. |
| **Arena**, at the far end | Two enemy soldiers and an ally on a navigation mesh. They fight each other, and the enemies turn on you when you are the nearest. |
| **Movement**, far right | A wall to slide down and jump off, and a ramp up to a ledge to glide from. |

The top left of the screen shows health, statuses, ammo, pools, ability cooldowns, the bag and
the main stats, so you can watch a ring, a shrine or a status change the numbers.

## Checking it without playing

```shell
godot --headless --fixed-fps 60 res://test_level/test_level.tscn -- --self-test
```

`self_test.gd` walks the player over every pickup, shrine and zone, fires, casts, drinks and
throws, and prints 18 checks; the exit code is 1 if one fails. Its first two checks are that
the level uses every class in `character_system/` and every file in the starter pack, so a new part can't be
left out of the level unnoticed.

## Files

- `scenes/player.tscn`: a first-person character with every component.
- `scenes/soldier.tscn`: an AI character; the level makes one of them an ally.
- `scenes/dummy.tscn`: a target with health, statuses and a head hurtbox.
- The pickups and nameplates come from `immunity_test/`.

Shots leave from the weapon in the player's hand and land where the crosshair is, at any
range: the `PlayerBrain` aims at the first thing the middle of the screen is on.
