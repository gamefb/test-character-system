@tool
class_name MotorNode
extends Node
## Base for the nodes under a [CharacterMotor]: [MovementMode] and [LayeredMove]. Extend one of
## those rather than this.
##
## It gives them [member motor], [member body] and [method stat], and the hooks the motor calls.
## Like a component, it can own stats with [method _stats], and statuses can change them.

## The motor this node is under. Set when it enters the tree.
var motor: CharacterMotor
## The character being moved. Set when it enters the tree.
var body: CharacterBody3D


func _notification(what: int) -> void:
	if what == NOTIFICATION_ENTER_TREE:
		motor = get_parent() as CharacterMotor
		body = motor.get_parent() as CharacterBody3D if motor else null
	elif what == NOTIFICATION_PARENTED:
		update_configuration_warnings()


func _get_configuration_warnings() -> PackedStringArray:
	if get_parent() is CharacterMotor:
		return PackedStringArray()
	return PackedStringArray(["Add this as a child of a CharacterMotor."])


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
