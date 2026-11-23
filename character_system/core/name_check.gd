@tool
class_name NameCheck
extends RefCounted
## Finds names in your data that nothing in the project recognizes, which is usually a typo.
##
## Stats, events and tags are typed as text, so [code]move_sped[/code] or
## [code]took_damgae[/code] would otherwise do nothing without any error. This checks:
## [br]- stat names in [StatModifier], [StatCondition], [StatAmount] and [ChanceCondition]
## against the stats components and movement modes and moves declare in
## [code]_stats()[/code], the ones listed in [member ComponentManager.stats] in your scenes, and the
## two each [Pool] adds ([code]resist_<type>[/code] and [code]bonus_<type>[/code] are always
## allowed),
## [br]- pool names in [ChangePoolEffect] and [member AbilityData.costs] against the [Pool]s
## in your scenes,
## [br]- [member StatusTrigger.event] against the events scripts send with
## [method ComponentManager.notify] or [method ComponentManager.send], and the ones the
## [CharacterMotor] sends for each mode and move with a [code]class_name[/code], such as
## [code]walk_mode_entered[/code],
## [br]- tags in [member StatusData.immune_to], [member StatusData.removes_tags],
## [member AbilityData.blocked_by_tags], [HasTagCondition] and [RemoveStatusEffect] against
## the tags your saved statuses have.
## [br]The editor shows the results above the Inspector (enable the Character System Warnings
## plugin) and as warnings on [Statuses], [Grants],
## [Abilities], [Hitscan] and [MeleeSweep].
##
## To check the resources your own component holds, return the results from its
## [method Component._warnings] (the script needs [code]@tool[/code]):
## [codeblock]
## func _warnings() -> PackedStringArray:
## 	return NameCheck.problems_in(effects)
## [/codeblock]
## It reads names written in the code and saved files, so a name built at runtime, such as
## [code]notify(host, my_event)[/code] with a variable, isn't seen; a trigger for it is
## reported even though it works. With the plugin enabled, the project is read again whenever
## its files change; otherwise at most every 30 seconds.

const _RESCAN_MS := 30000  # How long scan results are reused if nothing says files changed.

static var _scanned_at: int = -_RESCAN_MS
static var _stats := PackedStringArray()
static var _events := PackedStringArray()
static var _tags := PackedStringArray()
static var _pools := PackedStringArray()


## Problems in [param object] and the resources stored inside it, as messages.
## Resources saved in their own file are checked when you open them, not from here.
static func problems(object: Object) -> PackedStringArray:
	_scan()
	var out := PackedStringArray()
	_check(object, out, true)
	return out


## Problems in every resource in [param list].
static func problems_in(list: Array) -> PackedStringArray:
	var out := PackedStringArray()
	for item in list:
		if item is Object:
			out.append_array(problems(item))
	return out


## True for the kinds of resource this checks, directly or inside them.
static func handles(object: Object) -> bool:
	return (
			object is StatusData or object is StatusTrigger or object is StatModifier
			or object is Condition or object is Effect or object is AbilityData
			or object is Amount or object is ItemData
	)


## Stat names declared by components, e.g. move_speed.
static func known_stats() -> PackedStringArray:
	_scan()
	return _stats


## Event names some script sends, e.g. took_damage.
static func known_events() -> PackedStringArray:
	_scan()
	return _events


## Tags that saved statuses have, e.g. fire.
static func known_tags() -> PackedStringArray:
	_scan()
	return _tags


## Names of the [Pool]s in saved scenes, e.g. mana.
static func known_pools() -> PackedStringArray:
	_scan()
	return _pools


## Forgets the scan, so the next check reads the project again.
static func rescan() -> void:
	_scanned_at = -_RESCAN_MS


#region Checking


static func _check(object: Object, out: PackedStringArray, is_root: bool) -> void:
	if not object is Resource:
		return
	var res := object as Resource
	if not is_root and res.resource_path and not res.resource_path.contains("::"):
		# Saved in its own file: checked when that file is open.
		return
	# By property, not by class, so resources of your own are checked the same way.
	if &"stat" in object:
		_check_name(object.get(&"stat"), _stats, "stat",
				"No component has a stat called '%s', so this does nothing.", out, true)
	if object.get(&"bonus_stat"):
		_check_name(object.get(&"bonus_stat"), _stats, "stat",
				"Bonus Stat: no component has a stat called '%s'.", out, true)
	if object is Effect and &"pool" in object:
		_check_name(object.get(&"pool"), _pools, "pool",
				"No Pool in a saved scene is called '%s'.", out)
	if object is AbilityData:
		for pool_name in object.get(&"costs"):
			_check_name(pool_name, _pools, "pool",
					"Costs: no Pool in a saved scene is called '%s'.", out)
		for tag in object.get(&"blocked_by_tags"):
			_check_name(tag, _tags, "tag", "Blocked By Tags: no status has the tag '%s'.", out)
	if object is RemoveStatusEffect and object.get(&"tag"):
		_check_name(object.get(&"tag"), _tags, "tag", "No status has the tag '%s'.", out)
	if object is StatusTrigger:
		_check_name(object.get(&"event"), _events, "event",
				"No script sends an event called '%s', so this trigger never runs.", out)
	if object is HasTagCondition:
		_check_name(object.get(&"tag"), _tags, "tag",
				"No status has the tag '%s', so this never passes.", out)
	if object is StatusData:
		for tag in object.get(&"immune_to"):
			_check_name(tag, _tags, "tag", "Immune To: no status has the tag '%s'.", out)
		for tag in object.get(&"removes_tags"):
			_check_name(tag, _tags, "tag", "Removes Tags: no status has the tag '%s'.", out)
	for p in object.get_property_list():
		if not p.usage & PROPERTY_USAGE_STORAGE or p.name == "script":
			continue
		var value = object.get(p.name)
		if value is Array:
			for v in value:
				if v is Resource:
					_check(v, out, false)
		elif (
				value is Resource
				and not (value is Script or value is PackedScene or value is Texture)
		):
			_check(value, out, false)


static func _check_name(name, known: PackedStringArray, kind: String, message: String,
		out: PackedStringArray, allow_resist := false) -> void:
	var text := String(name)
	if text.is_empty():
		out.append("No %s set, so this does nothing." % kind)
		return
	# Damage types are open-ended, so their two stats can't be listed.
	if text in known or (allow_resist and (
			text.begins_with("resist_") or text.begins_with("bonus_"))):
		return
	var line: String = message % text
	var guess: String = _closest(text, known)
	if guess:
		line += " Did you mean '%s'?" % guess
	out.append(line)


static func _closest(text: String, known: PackedStringArray) -> String:
	var best := ""
	# Below this, the guess isn't worth showing.
	var best_score: float = 0.5
	for k in known:
		var score: float = text.similarity(k)
		if score > best_score:
			best = k
			best_score = score
	return best


#endregion


#region Scanning the project


static func _scan() -> void:
	if Time.get_ticks_msec() - _scanned_at < _RESCAN_MS:
		return
	_scanned_at = Time.get_ticks_msec()
	var stats := {}
	for stat_name in _component_stats():
		stats[stat_name] = true
	var events := {}
	var tags := {}
	var pools := {}
	# A ComponentManager's stats and a Pool's name, as saved in scenes.
	var listed := RegEx.create_from_string(
			"(?ms)^stats = Dictionary\\[StringName, float\\]\\(\\{(.*?)\\}\\)")
	var pool_line := RegEx.create_from_string("(?m)^pool = &\"(\\w+)\"")
	var send := RegEx.create_from_string("(?:send|notify)\\s*\\((?:[^,()]*,\\s*)?&?\"(\\w+)\"")
	var tag_line := RegEx.create_from_string("(?m)^tags = Array\\[StringName\\]\\(\\[(.*)\\]\\)")
	var name := RegEx.create_from_string("\"(\\w+)\"")
	for path in _files("res://"):
		var text: String = FileAccess.get_file_as_string(path)
		if path.ends_with(".gd"):
			for m in send.search_all(text):
				events[m.get_string(1)] = true
		else:
			for line in tag_line.search_all(text):
				for m in name.search_all(line.get_string(1)):
					tags[m.get_string(1)] = true
			for block in listed.search_all(text):
				for m in name.search_all(block.get_string(1)):
					stats[m.get_string(1)] = true
			for m in pool_line.search_all(text):
				pools[m.get_string(1)] = true
			if text.contains("/pool.gd\""):
				pools["mana"] = true  # The default name isn't saved in the scene.
	for pool_name in pools:
		stats["max_" + pool_name] = true
		stats[pool_name + "_regen"] = true
	for event in _motor_events():
		events[event] = true
	_stats = PackedStringArray(stats.keys())
	_events = PackedStringArray(events.keys())
	_tags = PackedStringArray(tags.keys())
	_pools = PackedStringArray(pools.keys())


# Stat names in the _stats() of every script that extends Component.
static func _component_stats() -> PackedStringArray:
	var base_of := {}
	var path_of := {}
	for c in ProjectSettings.get_global_class_list():
		base_of[c["class"]] = c["base"]
		path_of[c["class"]] = c["path"]
	var key := RegEx.create_from_string("\"(\\w+)\"\\s*:")
	var found := {}
	for cls in path_of:
		var c = cls
		while base_of.has(c) and c != &"Component" and c != &"MotorNode":
			c = base_of[c]
		if c != &"Component" and c != &"MotorNode":
			continue
		var source: String = FileAccess.get_file_as_string(path_of[cls])
		var start: int = source.find("\nfunc _stats(")
		if start == -1:
			continue
		var end: int = source.find("\nfunc ", start + 1)
		for m in key.search_all(source.substr(start, end - start if end != -1 else -1)):
			found[m.get_string(1)] = true
	return PackedStringArray(found.keys())


# The events the motor sends for every movement mode and layered move, e.g. walk_mode_entered.
static func _motor_events() -> PackedStringArray:
	var base_of := {}
	for c in ProjectSettings.get_global_class_list():
		base_of[c["class"]] = c["base"]
	var out := PackedStringArray()
	for cls in base_of:
		var c = cls
		while base_of.has(c) and c != &"MovementMode" and c != &"LayeredMove":
			c = base_of[c]
		var prefix := String(cls).to_snake_case()
		if c == &"MovementMode":
			out.append_array([prefix + "_entered", prefix + "_exited"])
		elif c == &"LayeredMove":
			out.append_array([prefix + "_started", prefix + "_finished"])
	return out


# Scripts, resources and scenes in the project, skipping addons and Godot's cache.
static func _files(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd") or f.ends_with(".tres") or f.ends_with(".tscn"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		if not d.begins_with(".") and d != "addons":
			out.append_array(_files(dir.path_join(d)))
	return out


#endregion
