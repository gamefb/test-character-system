@tool
extends Label
## Lists NameCheck's problems for [member target], and hides itself when there are none.
## Rechecks twice a second, so it updates as you type.

## The resource being inspected.
var target: Object

var _wait: float = 0.0


func _ready() -> void:
	autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_theme_color_override(&"font_color", Color(1.0, 0.75, 0.3))
	refresh()


func _process(delta: float) -> void:
	_wait -= delta
	if _wait <= 0.0:
		_wait = 0.5
		refresh()


## Checks [member target] again and shows what's wrong.
func refresh() -> void:
	var found := PackedStringArray()
	if is_instance_valid(target):
		found = NameCheck.problems(target)
	visible = not found.is_empty()
	text = "\n".join(Array(found).map(func(p: String) -> String: return "⚠ " + p))
