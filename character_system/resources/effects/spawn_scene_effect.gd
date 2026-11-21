class_name SpawnSceneEffect
extends Effect
## Spawns a scene where the target is, e.g. a puddle, an explosion or a loot drop.
##
## The scene is added to the level, not to the target, so it stays when the target moves or
## dies. Spawning an [EffectZone] lets a status leave ground that applies other statuses, such
## as a water spell leaving a puddle that makes everyone standing in it Wet.

## The scene to spawn. Its root must be a [Node3D].
@export var scene: PackedScene
## Seconds before the spawned scene is freed. 0 keeps it.
@export var lifetime: float = 0.0


func _execute(ctx: EffectContext) -> void:
	var target := ctx.target as Node3D
	if scene and target and target.is_inside_tree():
		# Effects can run inside physics callbacks, where areas can't be added yet.
		_spawn.call_deferred(target.get_tree(), target.global_position)


func _spawn(tree: SceneTree, where: Vector3) -> void:
	var spawned := scene.instantiate() as Node3D
	var level: Node = tree.current_scene if tree.current_scene else tree.root
	level.add_child(spawned)
	spawned.global_position = where
	if lifetime > 0.0:
		tree.create_timer(lifetime, false).timeout.connect(spawned.queue_free)
