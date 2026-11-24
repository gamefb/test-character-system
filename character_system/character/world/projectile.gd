@icon("res://character_system/icons/effect_zone.svg")
class_name Projectile
extends Node3D
## A shot that takes time to arrive: a rocket, a fireball, an arrow, a thrown grenade.
##
## Make a scene with this script on its root and a mesh or particles under it; it needs no
## collision shape. A [LaunchProjectileEffect] spawns it and hands it effects, from an ability
## ([member AbilityData.user_effects]) or a weapon ([member Trigger.user_effects]). It flies
## forward, and on the first thing it touches it applies
## [member effects] to that, then [member blast_effects] to everything within
## [member blast_radius], spawns [member impact_scene] and frees itself.
## [br][br]It moves with a ray each physics frame, so a fast one can't pass through a thin
## wall, and it never hits whoever launched it. A hit on a [Hurtbox] scales the effects and
## adds its tags, as with [Hitscan].
## [codeblock]
## # From your own code, e.g. a turret:
## Projectile.launch(rocket_scene, self, muzzle.global_position, target.global_position)
## [/codeblock]

## Emitted when it hits something, before its effects run. [param ctx] is the hit.
signal impacted(ctx: EffectContext)

## Metres per second.
@export_range(0.0, 200.0, 0.1, "or_greater", "suffix:m/s") var speed: float = 30.0
## How much of the level's gravity pulls on it: 0 flies straight, 1 arcs like a thrown rock.
@export_range(0.0, 2.0, 0.01, "or_greater") var gravity_scale: float = 0.0
## Seconds before it ends by itself. If it has a blast it goes off where it is; otherwise it
## just disappears.
@export_range(0.1, 30.0, 0.1, "or_greater", "suffix:s") var lifetime: float = 5.0
## Physics layers it can hit. Areas on these layers count too, so hurtboxes can be hit.
@export_flags_3d_physics var collision_mask: int = 0xffff_ffff
## Applied in order to what it hits directly, after any effects the launcher handed over.
@export var effects: Array[Effect] = []
## How far the blast reaches from the point of impact, in metres. 0 for no blast.
@export_range(0.0, 30.0, 0.1, "or_greater", "suffix:m") var blast_radius: float = 0.0
## Applied in order to everything within [member blast_radius], including what it hit and,
## unless a condition such as [IsHostileCondition] says otherwise, whoever launched it.
@export var blast_effects: Array[Effect] = []
## How strong the blast is at its edge, as a share of its strength at the centre. 1 is the
## same everywhere; 0.25 fades to a quarter. It scales [member EffectContext.magnitude].
@export_range(0.0, 1.0, 0.01) var blast_edge_strength: float = 1.0
## Spawned at the point of impact, e.g. an explosion or a scorch mark. Its root must be a
## [Node3D]. It isn't freed for you.
@export var impact_scene: PackedScene

## Who launched it. Its effects credit this node, and it's never hit directly.
var source: Node
## The item or ability behind it, for [member EffectContext.origin].
var origin: Resource
## Where it's heading, in metres per second. Set by [method launch] from [member speed].
var velocity := Vector3.ZERO

var _age: float = 0.0
var _excluded: Array[RID] = []


## Spawns [param scene] at [param from], flying toward [param toward], and returns it.
## [param p_source] is who launched it. [param extra_effects] run on what it hits, before the
## scene's own [member effects], so one projectile scene can serve several weapons.
## [param p_origin] is the item or ability behind it. The projectile is added to the level, so
## it keeps flying if its launcher is freed.
static func launch(scene: PackedScene, p_source: Node, from: Vector3, toward: Vector3,
		extra_effects: Array[Effect] = [], p_origin: Resource = null) -> Projectile:
	var tree: SceneTree = p_source.get_tree() if is_instance_valid(p_source) else null
	if not scene or not tree:
		return null
	var shot := scene.instantiate() as Projectile
	if not shot:
		push_error("Projectile.launch: the scene's root needs the Projectile script.")
		return null
	shot.source = p_source
	shot.origin = p_origin
	var all: Array[Effect] = []
	all.append_array(extra_effects)
	all.append_array(shot.effects)
	shot.effects = all
	var level: Node = tree.current_scene if tree.current_scene else tree.root
	level.add_child(shot)
	var direction: Vector3 = from.direction_to(toward)
	if direction.is_zero_approx():
		direction = Vector3.FORWARD
	shot.global_position = from
	shot.velocity = direction * shot.speed
	shot._face(direction)
	shot._excluded = Hurtbox.rids_of(p_source)
	return shot


## [param direction] turned by a random angle of up to [param degrees], for weapon spread.
## With 0 degrees it's returned unchanged.
static func spread_direction(direction: Vector3, degrees: float) -> Vector3:
	if degrees <= 0.0 or direction.is_zero_approx():
		return direction
	var side: Vector3 = direction.cross(Vector3.UP)
	if side.is_zero_approx():
		side = direction.cross(Vector3.RIGHT)
	var tilted: Vector3 = direction.rotated(side.normalized(), deg_to_rad(randf() * degrees))
	return tilted.rotated(direction.normalized(), randf() * TAU)


func _physics_process(delta: float) -> void:
	velocity += _gravity() * gravity_scale * delta
	var from: Vector3 = global_position
	var to: Vector3 = from + velocity * delta
	var query := PhysicsRayQueryParameters3D.create(from, to, collision_mask, _excluded)
	var hit: Dictionary = Hurtbox.raycast(get_world_3d().direct_space_state, query)
	if hit:
		global_position = hit.position
		_impact(Hurtbox.hit(source, hit.collider, origin, hit.position, hit.normal))
		return
	global_position = to
	if not velocity.is_zero_approx():
		_face(velocity.normalized())
	_age += delta
	if _age >= lifetime:
		if blast_radius > 0.0:
			_impact(null)
		else:
			queue_free()


# The level's gravity, in metres per second squared.
func _gravity() -> Vector3:
	var strength: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
	var direction: Vector3 = ProjectSettings.get_setting(
			"physics/3d/default_gravity_vector", Vector3.DOWN)
	return direction * strength


# Applies the effects at the point of impact and ends the projectile. ctx is the direct hit,
# or null when it went off without touching anything.
func _impact(ctx: EffectContext) -> void:
	set_physics_process(false)
	var where: Vector3 = global_position
	if ctx:
		impacted.emit(ctx)
		Effect.apply_all(effects, ctx)
	if blast_radius > 0.0:
		_blast(where)
	if impact_scene:
		var spawned := impact_scene.instantiate() as Node3D
		get_parent().add_child(spawned)
		spawned.global_position = where
	queue_free()


func _blast(where: Vector3) -> void:
	var sphere := SphereShape3D.new()
	sphere.radius = blast_radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis(), where)
	query.collision_mask = collision_mask
	query.collide_with_areas = true  # So hurtboxes count.
	# Character -> its context: one blast per character, however many of its parts are inside.
	var hits: Dictionary[Node, EffectContext] = {}
	for hit in get_world_3d().direct_space_state.intersect_shape(query, 64):
		var target: Node = hit.collider.character if hit.collider is Hurtbox else hit.collider
		if hits.has(target) or not is_instance_valid(target):
			continue
		var ctx := EffectContext.new(source, target, origin)
		ctx.position = where
		var node := target as Node3D
		if node and blast_edge_strength < 1.0:
			var closeness: float = 1.0 - clampf(
					node.global_position.distance_to(where) / blast_radius, 0.0, 1.0)
			ctx.magnitude = lerpf(blast_edge_strength, 1.0, closeness)
		hits[target] = ctx
	for ctx: EffectContext in hits.values():
		Effect.apply_all(blast_effects, ctx)


func _face(direction: Vector3) -> void:
	var up: Vector3 = Vector3.UP if absf(direction.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	look_at(global_position + direction, up)
