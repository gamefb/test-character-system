@tool
@icon("res://character_system/icons/health.svg")
class_name Health
extends Pool
## The pool named [code]health[/code]: what damage takes away and healing gives back.
##
## It is a [Pool], so everything that works on pools works on health: an ability can cost
## health, [code]max_health[/code] and [code]health_regen[/code] are stats, and a bar that
## shows a pool shows health. On top of that it has resistances and the events of dying.
## [br][br]
## [b]Death is a status.[/b] At zero the character gets [member death_status], which stays
## until [method revive]. Health itself only stops changing; what a dead character can't do
## is written on that status, in its [member StatusData.blocks]. Give a boss a different
## status, a "Downed" one that still lets it crawl, or leave the field empty for a game in
## which nothing dies.
## [br][br]
## [b]Events.[/b] [code]died[/code] is sent to the character when health reaches zero,
## [code]killed[/code] to whoever caused it, and [code]revived[/code] when health comes back.

## Emitted when health reaches zero. [param ctx] says who or what did it, or is null.
signal died(ctx: EffectContext)

## The status the character has while health is at zero. Empty: nothing happens at zero, apart
## from [signal died] and the event of the same name.
@export var death_status: StatusData = preload("res://character_system/core/statuses/dead.tres")
## Damage type to the base of [code]resist_<type>[/code]: 0.5 halves fire, 1 is immune, and a
## negative number is a weakness.
@export var resistances: Dictionary[StringName, float] = {}:
	set(value):
		resistances = value
		update_stats()


func _init() -> void:
	pool = &"health"


func _validate_property(property: Dictionary) -> void:
	# Fixed for health: its name, and the settings of other pools that mean nothing here.
	if property.name in [&"pool", &"status_while_empty", &"starts_full", &"absorbs_damage",
			&"absorbed_types"]:
		property.usage = PROPERTY_USAGE_NONE


func _stats() -> Dictionary[StringName, float]:
	var owned: Dictionary[StringName, float] = super()
	for type in resistances:
		owned[StringName("resist_" + type)] = resistances[type]
	return owned


## Whether health is at zero and the character has a [member death_status] to show for it.
func is_dead() -> bool:
	return death_status != null and not _fresh and _current <= 0.0


## Adds [param amount], or takes it away when it is negative. Nothing changes while dead:
## only [method revive] brings a character back.
func change(amount: float, ctx: EffectContext = null) -> void:
	if not is_dead():
		super(amount, ctx)


## Sets health to [param amount], or to the maximum if it is left out, and ends death.
func revive(amount := -1.0) -> void:
	_set_current(maximum() if amount < 0.0 else amount)


func _regenerates() -> bool:
	return not is_dead()


func _empty_status() -> StatusData:
	return death_status


func _emptied(ctx: EffectContext) -> void:
	died.emit(ctx)
	if manager:
		manager.send(&"died", ctx)
	if ctx and ctx.source != host:
		# Safe if the killer has no components or is already gone.
		ComponentManager.notify(ctx.source, &"killed", ctx)


func _refilled() -> void:
	if manager:
		manager.send(&"revived", null)
