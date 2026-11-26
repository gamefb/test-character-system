class_name IsHostileCondition
extends Condition
## Passes when whoever caused it is hostile to the target, e.g. so a weapon or an area attack
## doesn't hurt allies.
##
## Hostility comes from the source's [Faction]. A source without one, such as a trap or a zone,
## counts as hostile to everyone.


func _passes(ctx: EffectContext) -> bool:
	var faction := Faction.find_on(ctx.source)
	return faction == null or faction.is_hostile(ctx.target)
