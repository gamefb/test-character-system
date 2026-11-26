@tool
class_name MeleeSweep
extends WeaponDelivery
## Hits everything inside [member shape] on each [Trigger] shot, e.g. a sword swing.
##
## The shape sits [member offset] in front of the item and turns with it. Each character is hit
## once per swing, through the most vulnerable part inside the shape, so a [Hurtbox] head inside
## the swing scales the effects by its multiplier. The wielder is never hit.
## [br][br]With an [member active] time the swing stays dangerous for that long and the shape
## is checked along the path the item takes, so in an animated hand it follows the blade. The
## swing ends early if the wielder is stunned.

## How far the shape may move between two checks before another is made in between, so a
## fast blade can't pass through a thin target.
const MAX_GAP := 0.25

## The space a swing covers, e.g. a box about a metre across.
@export var shape: Shape3D:
	set(value):
		shape = value
		update_configuration_warnings()
## Where the shape's centre sits, relative to the item. The item's forward is -Z.
@export var offset := Vector3(0, 0, -1)
## Seconds the swing stays dangerous after the shot. The shape moves with the item, so in an
## animated hand it follows the blade. 0 checks once, in the frame of the shot.
@export_range(0.0, 5.0, 0.01, "or_greater", "suffix:s") var active: float = 0.0

var _left: float = 0.0
var _last: Transform3D
var _struck: Array[Node] = []


func _physics_process(delta: float) -> void:
	_left -= delta
	if (find(Trigger) as Trigger).is_blocked():
		_left = 0.0  # Stunned or killed mid-swing.
	else:
		_sweep()
	set_physics_process(_left > 0.0)


func _warnings() -> PackedStringArray:
	var out: PackedStringArray = super()
	if not shape:
		out.append("Set the Shape a swing covers.")
	return out


func _start() -> void:
	super()
	set_physics_process(false)


func _stop() -> void:
	set_physics_process(false)


func _fire() -> void:
	if not shape:
		return
	_struck.clear()
	_last = (host as Node3D).global_transform
	# At once, so an instant swing lands in the frame of the press.
	_sweep()
	_left = active
	set_physics_process(active > 0.0)


# Checks the shape from where it last was to where it is now, and hits who it hasn't yet.
func _sweep() -> void:
	var now: Transform3D = (host as Node3D).global_transform
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = collision_mask
	query.exclude = _wielder_rids
	var space: PhysicsDirectSpaceState3D = (host as Node3D).get_world_3d().direct_space_state
	var moved: float = (_last * offset).distance_to(now * offset)
	var steps: int = clampi(ceili(moved / MAX_GAP), 1, 8)
	for step in range(1, steps + 1):
		# The item's own turn is followed, so the shape goes round the arc, not across it.
		var at: Transform3D = _last.interpolate_with(now, float(step) / steps)
		query.transform = at.translated_local(offset)
		# Each character once a swing, on the strongest of its parts inside the shape.
		var hits: Dictionary[Node, Object] = Hurtbox.overlap(space, query)
		for target: Node in hits:
			if target not in _struck:
				_struck.append(target)
				Effect.apply_all(effects, context_for(hits[target], query.transform.origin))
	_last = now
