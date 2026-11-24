class_name CharacterHud
extends Control
## An example HUD to copy: shows a character's health, statuses, ammo and ability cooldowns.
##
## Attach it to a Control with a ProgressBar named HealthBar and three Labels named Statuses,
## Ammo and Cooldown, then set Character. Health and statuses update when they change;
## ammo and the cooldown are read every frame, which is cheap.

## The character to follow, e.g. the player.
@export var character: Node
## The ability whose cooldown is shown.
@export var ability: AbilityData

@onready var _health_bar: ProgressBar = $HealthBar
@onready var _statuses: Label = $Statuses
@onready var _ammo: Label = $Ammo
@onready var _cooldown: Label = $Cooldown


func _ready() -> void:
	var health := Health.find_on(character)
	health.changed.connect(_on_health_changed)
	_on_health_changed(health.current, health.maximum())
	Statuses.find_on(character).changed.connect(_on_statuses_changed)
	_on_statuses_changed()


func _process(_delta: float) -> void:
	_ammo.text = ""
	var gear := Equipment.find_on(character)
	if gear:
		var magazine := Magazine.find_on(gear.node_in(&"weapon"))
		if magazine:
			_ammo.text = "Ammo: %d" % magazine.rounds
	_cooldown.text = ""
	var abilities := Abilities.find_on(character)
	if abilities and ability:
		var left: float = abilities.cooldown_left(ability)
		_cooldown.text = "Ready" if left == 0.0 else "%.1f s" % left


func _on_health_changed(current: float, maximum: float) -> void:
	_health_bar.max_value = maximum
	_health_bar.value = current


func _on_statuses_changed() -> void:
	var names := PackedStringArray()
	for data: StatusData in Statuses.find_on(character).active:
		names.append(data.display_name)
	_statuses.text = ", ".join(names)
