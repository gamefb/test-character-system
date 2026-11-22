@tool
class_name MotorNode
extends Node
## Base for the nodes under a [CharacterMotor]: [MovementMode] and [LayeredMove]. Extend one of
## those rather than this.
##
## It gives them [member motor], [member body] and [method stat], and the hooks the motor calls.
## Like a component, it can own stats with [method _stats], and statuses can change them.
## [br][br]Statuses can also stop it, through [member blocked_by_tags], and the motor sends an
## event when it takes over or starts and when it hands over or ends, named after its class:
## e.g. [code]walk_mode_entered[/code] or [code]dash_move_started[/code]. Status triggers and
## components react to these like any other event.

## While the character has a status with one of these tags, this can't take over (a mode) or
## start (a move), e.g. [code]rooted[/code] on a dash. A mode in charge hands back to the
## motor's start mode, and a running move ends.
@export var blocked_by_tags: Array[StringName] = []

## The motor this node is under. Set when it enters the tree.
var motor: CharacterMotor
## The character being moved. Set when it enters the tree.
var body: CharacterBody3D
## The start of the events the motor sends for this node: its class name in snake_case, e.g.
## [code]walk_mode[/code] for [code]walk_mode_entered[/code].
var event_prefix: String


func _notification(what: int) -> void:
	if what == NOTIFICATION_ENTER_TREE:
		motor = get_parent() as CharacterMotor
		body = motor.get_parent() as CharacterBody3D if motor else null
		event_prefix = Component.type_name(get_script()).to_snake_case()
	elif what == NOTIFICATION_PARENTED:
		update_configuration_warnings()


func _get_configuration_warnings() -> PackedStringArray:
	if get_parent() is CharacterMotor:
		return PackedStringArray()
	return PackedStringArray(["Add this as a child of a CharacterMotor."])


## True while a status on the character has one of [member blocked_by_tags].
func is_blocked() -> bool:
	if blocked_by_tags.is_empty() or not motor:
		return false
	var statuses := motor.find(Statuses) as Statuses
	return statuses != null and blocked_by_tags.any(statuses.has_tag)


## Current value of [param stat_name] on this character, with statuses applied, e.g.
## [code]stat(&"move_speed")[/code]. See [method Component.stat].
func stat(stat_name: StringName) -> float:
	return motor.stat(stat_name) if motor else 0.0


## Re-reads [method _stats], e.g. from an export's setter.
func update_stats() -> void:
	if motor:
		motor.update_stats()



## The stats this node owns and their base values, as in [method Component._stats]. Call
## [method update_stats] when a base value changes.
func _stats() -> Dictionary[StringName, float]:
	return {}


## Called when it starts: a mode takes over, or a move begins.
func _enter() -> void:
	pass


## Called when it ends: another mode takes over, a move is done, or it's removed.
func _exit() -> void:
	pass


## Called every physics frame while it's running, before the body moves. Set
## [code]body.velocity[/code] here, and don't call [code]move_and_slide()[/code]: the motor
## does that once every mode and move is done.
func _physics_update(_delta: float) -> void:
	pass
