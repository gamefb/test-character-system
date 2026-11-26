@tool
@icon("res://character_system/icons/animator.svg")
class_name Animator
extends Component
## Plays an animation when the character hears an event. Nothing in the rules waits for it.
##
## Fill [member animations] in the Inspector: [code]weapon_started[/code] to a swing,
## [code]ability_cast_started[/code] to a cast, [code]died[/code] to a death. Timing stays
## with the rules: a weapon's [member Trigger.wind_up] and an ability's
## [member AbilityData.cast_time] decide when things happen, with or without this component.
## [br][br]To keep a clip in step, give it a marker named [member sync_marker] where the blade
## connects or the spell leaves the hand. The clip is then played faster or slower so that the
## marker lands on the shot: change a weapon's wind-up and its animation follows.
## [br][br]It drives an [AnimationPlayer]. With an [AnimationTree], leave this out and listen
## to the same events from the script that drives the tree.

## The player whose animations to play.
@export var player: AnimationPlayer:
	set(value):
		player = value
		update_configuration_warnings()
## Event name to animation name, e.g. [code]weapon_started[/code] to [code]swing[/code]. For
## one item or ability, add a colon and its id: [code]weapon_started:sword[/code]. That row
## wins over the plain one.
@export var animations: Dictionary[StringName, StringName] = {}:
	set(value):
		animations = value
		update_configuration_warnings()
## The marker that should land on the shot, or on the end of a cast. A clip without it plays
## at its own speed.
@export var sync_marker: StringName = &"hit"

# Event -> { id, or empty for any item or ability -> animation }.
var _clips: Dictionary[StringName, Dictionary] = {}


func _warnings() -> PackedStringArray:
	var out := PackedStringArray()
	if not player:
		out.append("Set the Player whose animations to play.")
	for key: StringName in animations:
		if key.get_slice(":", 0) not in NameCheck.known_events():
			out.append("Nothing sends an event called '%s'." % key.get_slice(":", 0))
		if player and not player.has_animation(animations[key]):
			out.append("The player has no animation called '%s'." % animations[key])
	return out


func _start() -> void:
	_clips.clear()
	for key: StringName in animations:
		var parts: PackedStringArray = key.split(":")
		var event := StringName(parts[0])
		if not _clips.has(event):
			_clips[event] = {}
			on(event, _play.bind(event))
		_clips[event][StringName(parts[1]) if parts.size() > 1 else &""] = animations[key]


func _play(ctx: EffectContext, event: StringName) -> void:
	var data := ctx.origin as DisplayData if ctx else null
	var id: StringName = data.id if data else &""
	var clip: StringName = _clips[event].get(id, _clips[event].get(&"", &""))
	if not player or not player.has_animation(clip):
		return
	var animation: Animation = player.get_animation(clip)
	var marker: float = 0.0
	if animation.has_marker(sync_marker):
		marker = animation.get_marker_time(sync_marker)
	# Faster or slower, so the marker is reached when the wind-up or cast ends.
	var speed: float = marker / ctx.duration if ctx and ctx.duration > 0.0 and marker > 0.0 else 1.0
	player.play(clip, -1.0, speed)
