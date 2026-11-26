@tool
@icon("res://character_system/icons/ability_data.svg")
class_name AbilityData
extends DisplayData
## An active ability: when it can be used, what it costs, who it targets and what it does.
##
## Put it in [member Abilities.slots] under an action name. Everything here is optional beyond
## [member effects]: an ability with only effects and a [member cooldown] fires the moment its
## button is pressed. Add [member costs] for mana or stamina, [member charges] to bank several
## uses, [member cast_time] for a wind-up that can be interrupted, and
## a name in [member blocked_by] so a status such as Silenced can stop it. Its name, icon and
## description come from [DisplayData].

@export_group("Use")
## Seconds before it can be used again. With [member charges], the time to regain one charge.
## The user's cooldown_speed stat speeds this up or slows it down.
@export var cooldown: float = 1.0
## How many uses can be banked. Each use takes one, and one comes back every
## [member cooldown] seconds. 1 is an ordinary cooldown.
@export_range(1, 10, 1, "or_greater") var charges: int = 1
## What each use takes from the user's [Pool]s, e.g. { &"mana": 20 }. It can't be used unless
## every pool has enough. Nothing is taken if the use fails or the cast is interrupted.
@export var costs: Dictionary[StringName, float] = {}
## It can only be used while all of these pass, e.g. a [PoolBelowCondition] for a last-stand
## heal. They're checked on the user: both sides of each condition are the user.
@export var conditions: Array[Condition] = []
## The names this ability answers to. It can't be used while a status that
## [member StatusData.blocks] one of them is active, and a cast in progress is interrupted when
## such a status arrives. Add a name to sort abilities into kinds, e.g. &"spells" for the ones
## a Silenced status should stop. Stuns need nothing here: they block the [Brain].
@export var blocked_by: Array[StringName] = [&"abilities"]

@export_group("Casting")
## Seconds between the press and the effects. 0 fires at once. Only one ability can be cast
## at a time; pressing another meanwhile fails.
@export var cast_time: float = 0.0
## Given to the user for as long as the cast lasts, e.g. a status that slows or roots them.
## Use a status with duration 0.
@export var status_while_casting: StatusData
## On: taking damage interrupts the cast.
@export var interrupted_by_damage := false

@export_group("Effects")
## Picks who the effects apply to. Leave empty to affect the user; use a [RadiusTargeting]
## for everyone nearby, or your own [Targeting] for anything else.
@export var targeting: Targeting
## On: it can't be used when [member targeting] finds nobody, and costs nothing. Off: it's
## used anyway, e.g. a shockwave that should play even if it hits no one.
@export var needs_target := false
## Run in order on each node [member targeting] returns.
@export var effects: Array[Effect] = []
## Run in order on the user each time the ability fires, whoever it targets, e.g. a
## [LaunchProjectileEffect] for a fireball, recoil, or the heal half of a life drain.
@export var user_effects: Array[Effect] = []
