@tool
@icon("res://character_system/icons/data_resource.svg")
@abstract
class_name DataResource
extends Resource
## Base class for the data you set up in the Inspector: statuses, abilities and items, and the
## effects, conditions, amounts and modifiers they're made of.
##
## It gives every one of them the same editor help. In a script that starts with
## [code]@tool[/code], an exported field with one of the usual names ([code]stat[/code],
## [code]pool[/code], [code]event[/code], [code]tag[/code], [code]tags[/code],
## [code]blocks[/code], [code]blocked_by[/code] and the keys of [code]costs[/code]) becomes a
## list to pick from, filled by [NameCheck] with the names the project already has. The
## Character System Warnings plugin also checks every resource built on this class for names
## nothing recognizes.
##
## You rarely extend it directly: a new effect extends [Effect], a new condition
## [Condition] and a new amount [Amount]. Extend it for a kind of data of your own that those
## don't cover, or [DisplayData] if players see it by name.


func _validate_property(property: Dictionary) -> void:
	if Engine.is_editor_hint():
		NameCheck.suggest(self, property)  # Name fields become lists to pick from.
