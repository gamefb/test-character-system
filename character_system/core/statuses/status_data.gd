class_name StatusData
extends Resource
## A status or passive, saved as a .tres file.
##
## A passive is a status with [member duration] 0. This resource is shared by every character
## that has the status, so it holds no runtime state; that lives in [Statuses].
##
## Tags drive interactions: [member immune_to] keeps out statuses with those tags,
## [member removes_tags] clears them, and [HasTagCondition] tests for them.

enum Stacking {
	## Reapplying resets the timer.
	REFRESH,
	## Reapplying adds a stack (up to max_stacks) and resets the timer.
	STACK,
	## Reapplying does nothing.
	IGNORE,
}

@export_group("Display")
## A unique name for your code, e.g. &"burning". Tags, not this, are what
## conditions and other statuses look for.
@export var id: StringName
## The name players see, e.g. in a status bar.
@export var display_name: String
## For your status UI. The system doesn't use it.
@export var icon: Texture2D
## Tooltip text for your UI.
@export_multiline var description: String

@export_group("Rules")
## Labels other statuses and conditions can look for, e.g. &"fire", &"wet".
@export var tags: Array[StringName] = []
## While this is active, statuses with any of these tags can't be added to the holder.
## Wet is immune to &"fire"; an Undead trait (an innate passive) is immune to &"poison".
## The thing that protects owns the rule, so a new fire status is covered by its tag alone.
@export var immune_to: Array[StringName] = []
## The status is only applied if all of these pass, e.g. "target's resist_fire is below 1".
## Use it for rules that aren't about other statuses. Checked each time something tries
## to apply it, not while it is active.
@export var apply_conditions: Array[Condition] = []
## Seconds. 0 = lasts until removed (passives from items, zones or the character itself).
@export var duration: float = 0.0
## What reapplying does while the status is active.
@export var stacking := Stacking.REFRESH
## The most stacks it can have. Only used with [constant STACK] stacking.
@export var max_stacks: int = 1
## Statuses with these tags are removed when this one is added, e.g. Wet puts out &"fire".
## Pair it with [member immune_to] to also keep them from coming back.
@export var removes_tags: Array[StringName] = []
## Ends every status that has a duration when this one is applied, e.g. for death or a cleanse.
@export var removes_timed := false
## What the character can't do, or can't have done to it, while this status is active. Each
## thing that can be blocked answers to a name, [code]&"abilities"[/code] by default for an
## ability, and a status that lists the name stops it. The names the system uses:
## [br]- [code]everything[/code]: the [Brain], so moving and every action.
## [br]- [code]movement[/code]: the [CharacterMotor]. [code]abilities[/code]: every
## [AbilityData]. [code]weapons[/code]: every [Trigger].
## [br]- [code]damage[/code] and [code]healing[/code]: a [DamageEffect] or [HealEffect] on
## this character does nothing.
## [br]- [code]targeting[/code]: shots pass through the character, and AI and area abilities
## leave it alone.
## [br]Add names of your own, such as [code]spells[/code], to a thing's Blocked By list.
@export var blocks: Array[StringName] = []

@export_group("Effects")
## Applied once per stack while active.
@export var modifiers: Array[StatModifier] = []
## Seconds between on_tick runs. 0 = never.
@export var tick_interval: float = 0.0
## Run on the holder each time a stack is added (once, for statuses that don't stack).
@export var on_apply: Array[Effect] = []
## Run every [member tick_interval] seconds while active, scaled by stacks.
@export var on_tick: Array[Effect] = []
## Run once when the status ends: it expires, is removed, or its last hold is dropped.
@export var on_remove: Array[Effect] = []
## Reactions to events such as &"taking_damage" while active. See [StatusTrigger].
@export var triggers: Array[StatusTrigger] = []


## How many stacks this status can have.
func stack_limit() -> int:
	return max_stacks if stacking == Stacking.STACK else 1


## True if [param target] isn't immune to this status and its [member apply_conditions] pass.
## UI can call this too, e.g. to show "Immune".
func can_apply(target: Node, source: Node = null) -> bool:
	var statuses := Component.of(target, Statuses) as Statuses
	if statuses and statuses.is_immune_to(self):
		return false
	return Condition.all_pass(apply_conditions, EffectContext.new(source, target, self))
