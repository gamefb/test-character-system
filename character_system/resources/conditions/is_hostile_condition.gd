class_name IsHostileCondition
extends Condition
## Passes when whoever caused it is hostile to the target, e.g. so a weapon or an area attack
## doesn't hurt allies.
##
## Hostility comes from the source's [Faction]. A source without one, such as a trap or a zone,
## counts as hostile to everyone. It looks at both sides, so it overrides
## [method Condition.check] instead of [method Condition._test], and
## [member Condition.subject] isn't used.


func check(ctx: EffectContext) -> bool:
	var faction := Component.of(ctx.source, Faction) as Faction
	var hostile: bool = faction == null or faction.is_hostile(ctx.target)
	return hostile != negate
