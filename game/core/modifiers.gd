## Modifier query service (skills, perk cards, assets, difficulty). Owner: LEAD (API).
## Contract: docs/contracts/modifiers.md (v1). Keys: game/contracts/modifier_keys.gd.
##
## Population (ENV B progression code / heist setup, on the SERVER):
##   Modifiers.set_source(crew_slot, &"skills", {&"stealth.body_bags_extra": 2, ...})
##   Modifiers.set_source(Modifiers.TEAM, &"asset.body_bag_case", {&"stealth.body_bags_extra": 2})
## Query (ENV A systems):
##   Modifiers.mult(slot, &"interaction.device_speed_mult")        -> float (1.0 default)
##   Modifiers.add(slot, &"stealth.body_bags_extra")               -> float (0 default)
##   Modifiers.flag(slot, &"stealth.silent_devices")               -> bool
##   Modifiers.params(slot, &"perk.stoic")                          -> Dictionary ({} if absent)
##   Modifiers.list(slot, &"weapon.hit_stack_buff")                -> Array[Dictionary] (one per source, LIST keys)
##   Several qualifiers at once: Modifiers.mult(slot, &"weapon.recoil_mult", [&"pistol", &"suppressed"])
##   Qualified keys: Modifiers.mult(slot, &"weapon.damage_mult", &"shotgun") combines
##   "weapon.damage_mult.shotgun" and "weapon.damage_mult.all".
## TEAM-scoped sources apply to every crew slot.
extends Node

const TEAM: int = -1

## slot -> source_name -> { key: value }
var _sources: Dictionary[int, Dictionary] = {}


func set_source(slot: int, source: StringName, values: Dictionary) -> void:
	for key: Variant in values:
		if not ModifierKeys.is_known(key):
			Log.error(&"modifiers", "unknown modifier key '%s' from source '%s'" % [key, source])
	if not _sources.has(slot):
		_sources[slot] = {}
	_sources[slot][source] = values


func clear_source(slot: int, source: StringName) -> void:
	if _sources.has(slot):
		_sources[slot].erase(source)


func clear_all() -> void:
	_sources.clear()


func mult(slot: int, key: StringName, qualifier: Variant = &"") -> float:
	var result: float = 1.0
	for v: Variant in _collect(slot, key, qualifier):
		result *= float(v)
	return result


func add(slot: int, key: StringName, qualifier: Variant = &"") -> float:
	var result: float = 0.0
	for v: Variant in _collect(slot, key, qualifier):
		result += float(v)
	return result


func flag(slot: int, key: StringName, qualifier: Variant = &"") -> bool:
	for v: Variant in _collect(slot, key, qualifier):
		if bool(v):
			return true
	return false


func params(slot: int, key: StringName) -> Dictionary:
	var found: Array = _collect(slot, key, &"")
	if found.is_empty():
		return {}
	return found[-1]


## LIST keys: every source's Dictionary (TEAM first, then the slot's sources), each tagged with
## "_source" (StringName). Empty if none.
func list(slot: int, key: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for s: int in [TEAM, slot]:
		if not _sources.has(s):
			continue
		var by_source: Dictionary = _sources[s]
		for source: Variant in by_source:
			var values: Dictionary = by_source[source]
			if not values.has(key):
				continue
			# A source may grant one Dictionary or an Array of them (one per skill/card, QB-38).
			var entries: Array = values[key] if values[key] is Array else [values[key]]
			for e: Variant in entries:
				var d: Dictionary = (e as Dictionary).duplicate()
				if not d.has("_source"):
					d["_source"] = source
				out.append(d)
	return out


## Snapshot for debugging / results screen.
func dump(slot: int) -> Dictionary:
	var out: Dictionary = {}
	for s: int in [TEAM, slot]:
		if _sources.has(s):
			out[s] = _sources[s].duplicate(true)
	return out


func _collect(slot: int, key: StringName, qualifier: Variant) -> Array:
	var keys: Array[StringName] = [key]
	var quals: Array = []
	if qualifier is Array:
		quals = qualifier
	elif StringName(qualifier) != &"":
		quals = [qualifier]
	if not quals.is_empty():
		keys = [StringName("%s.all" % key)]
		for q: Variant in quals:
			keys.append(StringName("%s.%s" % [key, q]))
	var out: Array = []
	for s: int in [TEAM, slot]:
		if not _sources.has(s):
			continue
		var by_source: Dictionary = _sources[s]
		for source: Variant in by_source:
			var values: Dictionary = by_source[source]
			for k: StringName in keys:
				if values.has(k):
					out.append(values[k])
	return out
