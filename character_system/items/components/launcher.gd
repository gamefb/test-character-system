@tool
@icon("res://character_system/icons/hitscan.svg")
class_name Launcher
extends ItemComponent
## Launches a [Projectile] on each [Trigger] shot: a rocket launcher, a bow, a wand.
##
## The projectile starts at the item and flies toward the wielder's
## [member Brain.aim_point]. [member effects] are handed to it and run on what it hits, so one
## projectile scene can serve several weapons; the blast and the look belong to the scene.

## The scene to launch. Its root needs the [Projectile] script.
@export var projectile: PackedScene:
	set(value):
		projectile = value
		update_configuration_warnings()
## Applied in order to what the projectile hits directly, before the projectile's own effects.
@export var effects: Array[Effect] = []
## Projectiles per shot, e.g. 3 for a volley.
@export_range(1, 20, 1, "or_greater") var count: int = 1
## How far, in degrees, a projectile may stray from the aim. 0 is perfectly accurate.
@export_range(0.0, 45.0, 0.1, "suffix:°") var spread: float = 0.0


func _warnings() -> PackedStringArray:
	var out: PackedStringArray = NameCheck.problems_in(effects)
	if not projectile:
		out.append("Set the Projectile scene to launch.")
	return out


func _requires() -> Array[Script]:
	return [Trigger]


func _start() -> void:
	listen((find(Trigger) as Trigger).fired, _launch)


func _launch() -> void:
	var muzzle := host as Node3D
	var from: Vector3 = muzzle.global_position
	var aim: Vector3 = from.direction_to(brain.aim_point)
	for i in count:
		var toward: Vector3 = from + Projectile.spread_direction(aim, spread)
		Projectile.launch(projectile, wielder, from, toward, effects, item.data if item else null)
