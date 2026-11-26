class_name SpawnSceneEffect
extends Effect
## Spawns a scene, e.g. a puddle, an explosion, a blood splash or a loot drop.
##
## The scene is added to the level, not to the target, so it stays when the target moves or
## dies. Spawning an [EffectZone] lets a status leave ground that applies other statuses, such
## as a water spell leaving a puddle that makes everyone standing in it Wet.

enum Where {
	## Where the target is.
	TARGET,
	## Where the hit landed, e.g. for sparks where a bullet struck. Falls back to the target
	## when the hit recorded no point.
	HIT_POINT,
	## Where whoever caused it is, e.g. a muzzle flash or a shockwave ring around the caster.
	SOURCE,
}

## The scene to spawn. Its root must be a [Node3D].
@export var scene: PackedScene
## Where to put it.
@export var at := Where.TARGET
## Seconds before the spawned scene is freed. 0 keeps it.
@export var lifetime: float = 0.0


func _execute(ctx: EffectContext) -> void:
	var anchor := (ctx.source if at == Where.SOURCE else ctx.target) as Node3D
	if not scene or not anchor or not anchor.is_inside_tree():
		return
	var where: Vector3 = anchor.global_position
	if at == Where.HIT_POINT and ctx.hit().position.is_finite():
		where = ctx.hit().position
	# Effects can run inside physics callbacks, where areas can't be added yet.
	_spawn.call_deferred(anchor.get_tree(), where)


func _spawn(tree: SceneTree, where: Vector3) -> void:
	var spawned := scene.instantiate() as Node3D
	var level: Node = tree.current_scene if tree.current_scene else tree.root
	level.add_child(spawned)
	spawned.global_position = where
	if lifetime > 0.0:
		tree.create_timer(lifetime, false).timeout.connect(spawned.queue_free)
