@icon("res://character_system/icons/effect_zone.svg")
class_name EffectZone
extends Area3D
## Affects bodies that enter or leave it, e.g. fire patches, water or a healing aura.
##
## Use [member status_while_inside] for states that last while inside (water, healing pads) and
## [member on_enter] for one-off effects (a fire patch's Burning). Shots pass through it, as
## through any area that isn't a [Hurtbox], and it has no collision layer, so sight lines and
## other physics queries do too.

## Given to each body while it is inside, e.g. Wet in deep water. Use a status with duration 0.
## Overlapping zones each hold it, so leaving one of two pools keeps the body wet.
@export var status_while_inside: StatusData
## Run once on each body that enters, e.g. apply a timed Burning.
@export var on_enter: Array[Effect] = []
## Run once on each body that leaves, e.g. a short timed Wet after leaving water.
@export var on_exit: Array[Effect] = []

# Bodies that accepted the status, so only their holds are dropped.
var _holding: Array[Node3D] = []


func _ready() -> void:
	# No collision layer, so sight lines and shape queries pass through the zone. It still
	# detects bodies, because detection uses its collision mask, not its layer.
	collision_layer = 0
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


# A zone that disappears (an evaporating puddle) lets go of everyone still inside.
func _exit_tree() -> void:
	for body in _holding.duplicate():
		_drop_hold(body)


func _on_body_entered(body: Node3D) -> void:
	var statuses := Statuses.find_on(body)
	if status_while_inside and statuses and statuses.add(status_while_inside):
		_holding.append(body)
	Effect.apply_all(on_enter, EffectContext.new(null, body))


func _on_body_exited(body: Node3D) -> void:
	_drop_hold(body)
	Effect.apply_all(on_exit, EffectContext.new(null, body))


func _drop_hold(body: Node3D) -> void:
	if body in _holding:
		_holding.erase(body)
		var statuses := Statuses.find_on(body)
		if statuses:
			statuses.drop_hold(status_while_inside)
